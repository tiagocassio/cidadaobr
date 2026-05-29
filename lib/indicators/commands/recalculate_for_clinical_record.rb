# frozen_string_literal: true

module Indicators
  class RecalculateForClinicalRecord < ApplicationCommand
    def initialize(clinical_record:)
      @clinical_record = clinical_record
    end

    def call
      citizen = resolve_citizen
      return { skipped: true } unless citizen

      indicator_codes = RecordTypeIndex.indicator_codes_for(@clinical_record.record_type)
      return { skipped: true } if indicator_codes.empty?

      DetectCitizenGaps.call(
        citizen_id: citizen.id,
        indicator_codes: indicator_codes,
        reference_date: reference_date
      )

      if citizen.care_team_id.present?
        RecalculateTeamScore.call(
          care_team_id: citizen.care_team_id,
          indicator_codes: indicator_codes,
          reference_date: reference_date
        )
      end

      { skipped: false, citizen_id: citizen.id, indicator_codes: indicator_codes }
    end

    private

    def resolve_citizen
      linked = @clinical_record.citizen
      return linked if linked

      @clinical_record.encounters.order(encounter_at: :desc).first&.citizen
    end

    def reference_date
      @clinical_record.encounter_at&.to_date || Date.current
    end
  end
end
