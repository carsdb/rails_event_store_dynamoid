module DynamoidReset
  def self.all
    Dynamoid.adapter.list_tables.each do |table|
      # only delete tables in our namespace
      if table =~ /^#{Dynamoid::Config.namespace}/
        Dynamoid.adapter.delete_table(table)
      end
    end

    Dynamoid.adapter.tables.clear

    # Recreate all tables to avoid unexpected errors
    Dynamoid.included_models.each(&:create_table)
  end
end

# Reduce noice in test output
Dynamoid.logger.level = Logger::WARN
