require 'spec_helper'
require 'ruby_event_store'
require 'ruby_event_store/spec/event_repository_lint'
require 'byebug'

describe RailsEventStoreDynamoid::EventRepository do

  subject { RailsEventStoreDynamoid::EventRepository.new }
  let(:test_link_events_to_stream ) { true }
  let(:test_expected_version_auto ) { true }
  let(:test_race_conditions_any ) { false }
  let(:test_race_conditions_auto ) { false }
  let(:test_binary) { false }

  it_behaves_like :event_repository, described_class

  it "has an adapter" do
    expect(subject).to respond_to(:adapter)
  end

end
