$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'support/dynamoid'
require 'support/dynamoid_reset'

RSpec.configure do |config|
  config.before(:each) do
    DynamoidReset.all
  end
end

require 'rails_event_store_dynamoid'
