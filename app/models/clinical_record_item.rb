# frozen_string_literal: true

class ClinicalRecordItem < ApplicationRecord
  belongs_to :clinical_record
  has_many :encounters, dependent: :destroy

  validates :clinical_record_id, :sequence, presence: true
  validates :sequence, uniqueness: { scope: :clinical_record_id }
end
