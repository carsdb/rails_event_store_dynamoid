require 'spec_helper'

describe RailsEventStoreDynamoid::Event do

	let(:default_attributes) do
    {
      stream: "user#1",
      event_id: "1010a012-111231112540-aacc",
      event_type: "UserRegistered",
      position: 1,
      meta: {
        session_id: "1188a0a0113c00ef",
        remote_ip: "127.0.0.1",
        user_agent: ""
      },
      data: {
        email: "john@example.com",
        from_mobile: false,
        type: 1,
        nilable_field: nil,
        empty_string: ""
      }
    }
  end

  let(:default_instance) { described_class.new(default_attributes) }


  it "can be instantiated" do
    expect { described_class.new }.not_to raise_error
  end

  it "can be instantiated with possible default attributes" do
    expect { default_instance }.not_to raise_error
  end

  it "can be created with default attributes" do
    expect(default_instance.save).to be_truthy
  end

  it "has an index for stream" do
    expect(described_class.global_secondary_indexes.keys).to include("stream")
  end
end
