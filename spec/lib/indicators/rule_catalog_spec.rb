# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::RuleCatalog do
  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  describe ".appointment_dependent_codes" do
    it "includes indicators whose dsl references appointments" do
      expect(described_class.appointment_dependent_codes).to include("C1")
    end
  end

  describe ".references_appointments?" do
    it "detects appointment numerator clauses" do
      clause = { "type" => "appointment_in_quadrimester", "statuses" => %w[scheduled] }

      expect(described_class.references_appointments?(clause)).to be(true)
    end

    it "detects nested appointment clauses" do
      clause = {
        "all" => [
          { "type" => "encounter_in_window", "within_months" => 12 },
          { "type" => "appointment_in_quadrimester", "statuses" => %w[scheduled] }
        ]
      }

      expect(described_class.references_appointments?(clause)).to be(true)
    end
  end
end
