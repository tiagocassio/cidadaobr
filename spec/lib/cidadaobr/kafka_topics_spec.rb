# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cidadaobr::KafkaTopics do
  it "uses hyphen-separated topic names without dots or underscores" do
    described_class::ALL.each do |topic|
      expect(topic).to match(/\A[a-z0-9]+(-[a-z0-9]+)*\z/)
      expect(topic).not_to include(".")
      expect(topic).not_to include("_")
    end
  end

  it "uses the same string for event_type and Kafka topic" do
    described_class::ALL.each do |name|
      expect(described_class.topic_for(name)).to eq(name)
    end
  end
end
