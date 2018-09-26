module RailsEventStoreDynamoid
  class EventRepository

    POSITION_SHIFT = 1
    SERIALIZED_GLOBAL_STREAM_NAME = "all".freeze

    attr_reader :adapter
    def initialize(adapter: ::RailsEventStoreDynamoid::Event)
      @adapter = adapter
    end

    def create(event, stream_name)
      byebug
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
      raise RubyEventStore::ReservedInteralName if spec.stream_name.eql?(EventRepository::SERIALIZED_GLOBAL_STREAM_NAME)

      stream = Event.where(stream: normalize_stream_name(spec))
      # FIXME stream = stream.order(position: order(spec.direction)) unless spec.global_stream?
      stream = stream.record_limit(spec.count) if spec.limit?
      stream = stream.where(start_condition(spec)) unless spec.head?
      # FIXME stream = stream.order(id: order(spec.direction))

      if spec.batched?
      else
      end

      byebug
      stream.map(&method(:build_event_entity)).each
    end

    def append_to_stream(events, stream, expected_version)
      add_to_stream(normalize_to_array(events), stream, expected_version, true) do |event|
        build_event_record(event).save!
        event.event_id
      end
      self
    end

    def link_to_stream(event_ids, stream, expected_version)
      self
    end

    def delete_stream(stream_name)
      adapter.where(stream: stream_name).delete_all
    end

    def has_event?(event_id)
      !adapter.find_by_id(event_id).nil?
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

    private

    def add_to_stream(collection, stream, expected_version, include_global, &to_event_id)
      # FIXME: There's no order given here to actually get the last position
      last_stream_version = -> (stream_) { Event.where(stream: stream_.name).first.try(:position) }
      resolved_version = expected_version.resolve_for(stream, last_stream_version)

      # Transaction starts
      in_stream = collection.flat_map.with_index do |element, index|
        position = compute_position(resolved_version, index)
        event_id = to_event_id.call(element)
        collection = []
        collection.unshift({
          stream: SERIALIZED_GLOBAL_STREAM_NAME,
          position: nil,
          event_id: event_id,
        }) if include_global
        collection.unshift({
          stream: stream.name,
          position: position,
          event_id: event_id
        }) unless stream.global?
        collection
      end
      byebug
      Event.import(in_stream)
      # Transaction ends

      self
    end

    def build_event_record(serialized_record)
      Event.new(
        id:         serialized_record.event_id,
        data:       serialized_record.data,
        meta:       serialized_record.metadata,
        event_type: serialized_record.event_type
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

    def build_event_entity(record)
      return nil unless record
      record.event_type.constantize.new(
        event_id: record.event_id,
        metadata: record.meta,
        data: record.data,
      )
    end

    def normalize_stream_name(specification)
      specification.global_stream? ? SERIALIZED_GLOBAL_STREAM_NAME : specification.stream_name
    end
  end
end
