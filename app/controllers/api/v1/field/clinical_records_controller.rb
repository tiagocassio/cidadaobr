# frozen_string_literal: true

module Api
  module V1
    module Field
      class ClinicalRecordsController < Api::BaseController
        def validate
          clinical_record = ClinicalRecord.find_by!(id: params[:id])
          result = Ledi::ValidateClinicalRecord.call(clinical_record_id: clinical_record.id)
          clinical_record.reload

          render json: {
            clinical_record_id: clinical_record.id,
            valid: result.valid,
            errors: result.errors,
            validation_errors: clinical_record.validation_errors
          }, status: result.valid ? :ok : :unprocessable_entity
        end
      end
    end
  end
end
