# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scheduling::ErrorMessages do
  def slot_unavailable_codes_in_codebase
    Dir[Rails.root.join("lib/scheduling/**/*.rb")].flat_map do |path|
      File.read(path).scan(/SlotUnavailableError\.raise!\(:([a-z_]+)\)/).flatten
    end.uniq
  end

  describe ".slot_unavailable_message" do
    it "maps known scheduling errors to pt-BR messages" do
      error = begin
        Scheduling::Errors::SlotUnavailableError.raise!(:slot_full)
      rescue Scheduling::Errors::SlotUnavailableError => e
        e
      end

      expect(described_class.slot_unavailable_message(error)).to eq(
        I18n.t("cidadaobr.scheduling.slot_unavailable.slot_full")
      )
    end

    it "falls back to a generic message for unknown errors" do
      error = Scheduling::Errors::SlotUnavailableError.new("unexpected")

      expect(described_class.slot_unavailable_message(error)).to eq(
        I18n.t("cidadaobr.scheduling.slot_unavailable.generic")
      )
    end

    it "maps every SlotUnavailableError code raised in lib/scheduling" do
      codes = slot_unavailable_codes_in_codebase

      expect(codes).not_to be_empty
      expect(codes).to all(satisfy { |code| Scheduling::Errors::SlotUnavailableError::CODES.key?(code.to_sym) })
    end

    it "maps every SlotUnavailableError code to an I18n key" do
      Scheduling::Errors::SlotUnavailableError::CODES.each_key do |code|
        expect(I18n.t("cidadaobr.scheduling.slot_unavailable.#{code}")).to be_present
      end
    end
  end
end
