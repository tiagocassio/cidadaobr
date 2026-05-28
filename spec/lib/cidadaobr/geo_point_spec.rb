# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cidadaobr::GeoPoint do
  describe ".from_payload" do
    it "builds a point from valid Brazilian coordinates" do
      point = described_class.from_payload(latitude: -23.5505, longitude: -46.6333)

      expect(point.x).to be_within(0.0001).of(-46.6333)
      expect(point.y).to be_within(0.0001).of(-23.5505)
    end

    it "returns nil for coordinates outside Brazil" do
      expect(described_class.from_payload(latitude: 40.7128, longitude: -74.006)).to be_nil
    end

    it "returns nil when coordinates are missing" do
      expect(described_class.from_payload(latitude: nil, longitude: -46.6333)).to be_nil
    end
  end

  describe ".from_clinical_record_payload" do
    it "reads coordinates from the FCD payload root" do
      point = described_class.from_clinical_record_payload("latitude" => -23.5505, "longitude" => -46.6333)

      expect(point.y).to be_within(0.0001).of(-23.5505)
    end
  end

  describe ".bbox_polygon" do
    it "builds a polygon for a valid bounding box" do
      polygon = described_class.bbox_polygon(
        sw_lat: -23.58,
        sw_lng: -46.65,
        ne_lat: -23.52,
        ne_lng: -46.61
      )

      expect(polygon).to be_present
    end

    it "returns nil for an inverted bounding box" do
      polygon = described_class.bbox_polygon(
        sw_lat: -23.52,
        sw_lng: -46.61,
        ne_lat: -23.58,
        ne_lng: -46.65
      )

      expect(polygon).to be_nil
    end
  end
end
