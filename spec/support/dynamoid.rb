require 'dynamoid'

Dynamoid.configure do |config|
  config.endpoint = "http://localhost:8000"
  config.namespace = "rails_event_store_dynamoid_test"
end

