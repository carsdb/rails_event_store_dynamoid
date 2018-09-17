$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'rails_event_store_dynamoid'

Dynamoid.configure do |config|
  config.endpoint = "http://localhost:8000"
end
