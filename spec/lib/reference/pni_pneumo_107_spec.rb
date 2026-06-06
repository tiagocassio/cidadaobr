# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reference::PniCalendarDefinitions do
  it "includes Pneumocócica 20 (107) for elderly calendar" do
    codes = described_class.elderly_entries.map { |entry| entry.fetch("immunobiological_code") }

    expect(codes).to include("107")
  end
end
