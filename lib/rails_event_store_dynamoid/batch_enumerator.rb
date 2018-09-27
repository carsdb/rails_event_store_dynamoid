module RailsEventStoreDynamoid
  class BatchEnumerator
    def initialize(batch_size, spec, reader)
      @batch_size  = batch_size
      @total_limit = spec.limit? ? spec.count : Float::INFINITY
      @direction   = spec.direction
      @reader      = reader
    end

    def each
      return to_enum unless block_given?

      last_created_at = nil

      (0...total_limit).step(batch_size) do |batch_offset|
        batch_offset = Integer(batch_offset)
        batch_limit  = [batch_size, total_limit - batch_offset].min

        offset_condition = {}
        if last_created_at
          if direction == :forward
            offset_condition = {'created_at.gt': last_created_at}
          else
            offset_condition = {'created_at.lt': last_created_at}
          end
        end

        result, last_created_at = reader.call(offset_condition, batch_limit)

        break if result.empty?
        yield result
      end
    end

    private

    attr_accessor :batch_size, :total_limit, :direction, :reader
  end
end
