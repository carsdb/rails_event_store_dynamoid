module RailsEventStoreDynamoid
  class EventRepository

    POSITION_SHIFT = 1
    SERIALIZED_GLOBAL_STREAM_NAME = "all".freeze

    attr_reader :adapter
    def initialize(adapter: ::RailsEventStoreDynamoid::Event)
      @adapter = adapter
    end

    def create(event, stream_name)
      adapter.create(
        stream:     stream_name,
        id:         event.event_id,
        event_type: event.class,
        data:       event.data,
        meta:       event.metadata,
      )
      event
    end

    def read(spec)
      adapter.read(spec)
    end

    def append_to_stream(events, stream, expected_version)
      add_to_stream(normalize_to_array(events), stream, expected_version, true)

      self
    end

    def link_to_stream(event_ids, stream, expected_version)
      normalized_event_ids = normalize_to_array(event_ids)
      found_events = []
      normalized_event_ids.each do |event_id|
        if event = Event.where(id: event_id).first
          found_events << build_event_instance(event)
        end
      end

      (normalized_event_ids - found_events.map(&:event_id)).each do |id|
        raise RubyEventStore::EventNotFound.new(id)
      end

      add_to_stream(found_events, stream, expected_version, nil)

      self
    end

    def delete_stream(stream_name)
      adapter.where(stream: stream_name).delete_all
    end

    def has_event?(event_id)
      adapter.where(id: event_id).count > 0
    end

    def last_stream_event(stream_name)
      build_event_entity(adapter.where(stream: stream_name).desc(:created_at).first)
    end

    def read_events_forward(stream_name, start_event_id, count)
      stream = adapter.where(stream: stream_name)
      unless start_event_id.equal? :head
        starting_event = adapter.find_by_id(id: start_event_id)
        stream = stream.start(starting_event)
      end

      # FIXME: order by ascending timestamp
      stream.record_limit(count)
        .map(&method(:build_event_entity))
    end

    def build_event_instance(dynamoid_record)
      RubyEventStore::SerializedRecord.new(
        event_id:   dynamoid_record.id,
        metadata:   dynamoid_record.meta,
        data:       dynamoid_record.data,
        event_type: dynamoid_record.event_type,
      )
    end

    private

    def add_to_stream(collection, stream, expected_version, include_global)
      # FIXME: There's no order given here to actually get the last position
      last_stream_version = -> (stream_) { Event.where(stream: stream_.name).first.try(:position) }
      resolved_version = expected_version.resolve_for(stream, last_stream_version)

      # Transaction starts
      in_stream = collection.flat_map.with_index do |element, index|
        position = compute_position(resolved_version, index)

        collection = []

        if include_global
          collection << build_event_record_hash(element, SERIALIZED_GLOBAL_STREAM_NAME, nil)
        end

        unless stream.global?
          collection << build_event_record_hash(element, stream.name, position)
        end
        collection
      end

      Event.import(in_stream)

      self
    end

    def build_event_record_hash(serialized_record, stream, position)
      {
        id:         serialized_record.event_id,
        stream:     stream,
        position:   position,
        data:       serialized_record.data,
        meta:       serialized_record.metadata,
        event_type: serialized_record.event_type
      }
    end

    def build_event_entity(record)
      return nil unless record
      record.event_type.constantize.new(
        event_id: record.event_id,
        metadata: record.meta,
        data: record.data,
      )
    end

    def normalize_to_array(events)
      return events if events.is_a?(Enumerable)
      [events]
    end

    def compute_position(resolved_version, index)
      unless resolved_version.nil?
        resolved_version + index + POSITION_SHIFT
      end
    end

    def normalize_stream_name(specification)
      specification.global_stream? ? SERIALIZED_GLOBAL_STREAM_NAME : specification.stream_name
    end
  end
end
