# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rails_event_store_dynamoid/version'

Gem::Specification.new do |spec|
  spec.name          = "rails_event_store_dynamoid"
  spec.version       = RailsEventStoreDynamoid::VERSION
  spec.authors       = ["mmhan"]
  spec.email         = ["mike.myatminhan@gmail.com"]

  spec.summary       = %q{Dyanmoid repository for RailsEventStore.}
  spec.description   = %q{Repository implementaion of RailsEventStore for Amazon Web Services' DynamoDB.}
  spec.homepage      = "TODO: Put your gem's website or public repo URL here."
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rspec"

  spec.add_dependency 'dynamoid', '>= 2.2.0'
  spec.add_dependency 'ruby_event_store', '~> 0.31.1'
  spec.add_dependency 'rails_event_store', '~> 0.31.1'
end
