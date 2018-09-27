require 'dynamoid'
require 'aws-sdk-core'

module RailsEventStoreDynamoid
  class Event
    include Dynamoid::Document

    range :stream, :string

    field :event_type, :string
    field :meta, :raw
    field :data, :raw

    field :position, :integer

    global_secondary_index hash_key: :stream, range_key: :created_at, projected_attributes: :all
    global_secondary_index hash_key: :stream, range_key: :position, projected_attributes: :all

    before_save :sanitize_raw_fields

    def self.read(spec)
      raise RubyEventStore::ReservedInteralName if spec.stream_name.eql?(EventRepository::SERIALIZED_GLOBAL_STREAM_NAME)

      stream = Event.where(stream: normalize_stream_name(spec))
      stream = stream.where(start_condition(spec)) unless spec.head?
      stream = stream.record_limit(spec.count) if spec.limit?
      stream = stream.scan_index_forward(spec.direction == :forward)

      if spec.batched?
        # # Do some maintenance on the entire table without flooding DynamoDB
        # Address.all(batch_size: 100).each { |address| address.do_some_work; sleep(0.01) }
        # Address.record_limit(10_000).batch(100).each { … } # Batch specified as part of a chain
        # FIXME
        # batch_read = -> (offset, limit) { stream.record_limit(limit). }
        stream.map(&method(:build_event_instance)).each
      else
        stream.map(&method(:build_event_instance)).each
      end
    end

    def self.has_duplicate?(serialized_record, stream_name, linking_event_to_another_stream)
      if linking_event_to_another_stream
        Event.where(id: serialized_record.event_id).count > 1
      else
        Event.where(id: serialized_record.event_id, stream: stream_name).count > 0
      end
    end

    private

    def sanitize_raw_fields
      self.meta = _sanitize_hash(self.meta) if self.meta.is_a?(Hash)
      self.data = _sanitize_hash(self.data) if self.data.is_a?(Hash)
    end

    def _sanitize_hash(hash)
      hash.reject do |k, v|
        v.nil? || ((v.is_a?(Set) || v.is_a?(String)) && v.empty?)
      end
    end

    def self.normalize_stream_name(specification)
      specification.global_stream? ? EventRepository::SERIALIZED_GLOBAL_STREAM_NAME : specification.stream_name
    end

    def self.start_condition(spec)
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

    def self.build_event_instance(dynamoid_record)
      RubyEventStore::SerializedRecord.new(
        event_id:   dynamoid_record.id,
        metadata:   dynamoid_record.meta,
        data:       dynamoid_record.data,
        event_type: dynamoid_record.event_type,
      )
    end

  end
end
