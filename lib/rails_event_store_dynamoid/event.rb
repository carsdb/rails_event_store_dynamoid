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
  end
end
