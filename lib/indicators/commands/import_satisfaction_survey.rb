# frozen_string_literal: true

module Indicators
  class ImportSatisfactionSurvey < ApplicationCommand
    Row = Data.define(:ine, :reference_month, :score)
    Result = Data.define(:imported, :skipped_unknown_ine, :skipped_invalid)

    SCORE_RANGE = (0..10).freeze

    def initialize(municipality:, rows:)
      @municipality = municipality
      @rows = rows
    end

    def call
      imported = 0
      skipped_unknown_ine = 0
      skipped_invalid = 0

      @rows.each do |row|
        unless self.class.valid_row?(row)
          skipped_invalid += 1
          next
        end

        team = CareTeam.find_by(municipality_id: @municipality.id, ine: row.ine)
        unless team
          skipped_unknown_ine += 1
          next
        end

        record = TeamSatisfactionSurveyScore.find_or_initialize_by(
          municipality: @municipality,
          care_team: team,
          reference_month: row.reference_month.beginning_of_month
        )
        record.score = row.score
        record.save!
        imported += 1
      end

      Result.new(
        imported: imported,
        skipped_unknown_ine: skipped_unknown_ine,
        skipped_invalid: skipped_invalid
      )
    end

    def self.from_csv(municipality:, csv_path:)
      rows = []
      skipped_invalid = 0

      CSV.read(csv_path, headers: true).each do |line|
        reference_month = Date.parse(line["reference_month"].to_s.strip)
        rows << Row.new(
          ine: line["ine"].to_s.strip,
          reference_month: reference_month,
          score: line["score"].to_f
        )
      rescue ArgumentError, TypeError
        skipped_invalid += 1
      end

      result = call(municipality: municipality, rows: rows)
      Result.new(
        imported: result.imported,
        skipped_unknown_ine: result.skipped_unknown_ine,
        skipped_invalid: result.skipped_invalid + skipped_invalid
      )
    end

    def self.valid_row?(row)
      row.ine.present? &&
        row.reference_month.is_a?(Date) &&
        SCORE_RANGE.cover?(row.score)
    end
  end
end
