# frozen_string_literal: true

module Api
  module V1
    module Field
      class ClinicalRecordsController < Api::BaseController
        def validate
          clinical_record = ClinicalRecord.find_by!(id: params[:id])
          result = CommandBus.dispatch(Ledi::ValidateClinicalRecord, clinical_record_id: clinical_record.id)
          clinical_record.reload

          @clinical_record = clinical_record
          @validation_passed = result.valid
          @ledi_errors = result.errors
          @validation_errors = clinical_record.validation_errors

          render status: @validation_passed ? :ok : :unprocessable_entity
        end
      end
    end
  end
end
