module RailsEventStoreDynamoid
  class EventRepositoryReader

    def has_event?(event_id)
      Event.where(id: event_id).count > 0
    end

    def last_stream_event(stream)
      record = RailsEventStoreDynamoid::Event
        .where(stream: stream.name)
        .scan_index_forward(false)
        .first
      build_event_instance(record)
    end

    def read_event(event_id)
      if record = RailsEventStoreDynamoid::Event.where(id: event_id).first
        build_event_instance(record)
      else
        raise RubyEventStore::EventNotFound.new(event_id)
      end
    end

    def read(spec)
      raise RubyEventStore::ReservedInteralName if spec.stream_name.eql?(EventRepository::SERIALIZED_GLOBAL_STREAM_NAME)

      stream = Event.where(stream: normalize_stream_name(spec))
      stream = stream.where(start_condition(spec)) unless spec.head?
      stream = stream.record_limit(spec.count) if spec.limit?
      stream = stream.scan_index_forward(spec.direction == :forward)

      if spec.batched?
        batch_reader = -> (offset_condition, limit) do
          last_created_at = nil

          result = stream
            .where(offset_condition)
            .record_limit(limit)
            .map do |event_|
              last_created_at = event_.created_at
              build_event_instance(event_)
            end

          [result, last_created_at]
        end
        RailsEventStoreDynamoid::BatchEnumerator.new(spec.batch_size, spec, batch_reader).each
      else
        stream.map(&method(:build_event_instance)).each
      end
    end

    private

    def normalize_stream_name(specification)
      specification.global_stream? ? EventRepository::SERIALIZED_GLOBAL_STREAM_NAME : specification.stream_name
    end

    def start_condition(spec)
      event_record = Event.find(spec.start, range_key: normalize_stream_name(spec), consistent_read: true)

      attribute, value = '', ''

      if spec.global_stream?
        attribute = 'created_at'
        value = event_record.created_at
      else
        attribute = 'position'
        value = event_record.position
      end

      case spec.direction
      when :forward
        {"#{attribute}.gt": value}
      else
        {"#{attribute}.lt": value}
      end
    end

    def build_event_instance(dynamoid_record)
      return nil unless dynamoid_record

      RubyEventStore::SerializedRecord.new(
        event_id:   dynamoid_record.id,
        metadata:   dynamoid_record.meta,
        data:       dynamoid_record.data,
        event_type: dynamoid_record.event_type,
      )
    end
  end
end