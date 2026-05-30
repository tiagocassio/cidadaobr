# frozen_string_literal: true

class ReferenceImportRun < ApplicationRecord
  STATUSES = %w[running succeeded failed].freeze

  validates :job_name, :status, :started_at, presence: true
  validates :status, inclusion: { in: STATUSES }

  def finish!(status:, records_imported: nil, error_message: nil)
    update!(
      status: status,
      records_imported: records_imported || self.records_imported,
      error_message: error_message,
      finished_at: Time.current
    )
  end
end
