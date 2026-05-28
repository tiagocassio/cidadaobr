# frozen_string_literal: true

module Ledi
  class ProjectionRunner
    ENCOUNTER_RECORD_TYPES = Projectors::EncounterProjector::ENCOUNTER_RECORD_TYPES

    def self.call(clinical_record:)
      case clinical_record.record_type
      when "FCI"
        Projectors::CitizenProjector.call(clinical_record: clinical_record)
      when "FCD"
        Projectors::HouseholdProjector.call(clinical_record: clinical_record)
      when *ENCOUNTER_RECORD_TYPES
        Projectors::EncounterProjector.call(clinical_record: clinical_record)
      end
    end
  end
end
