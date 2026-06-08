# frozen_string_literal: true

class Citizen < ApplicationRecord
  belongs_to :municipality
  belongs_to :health_facility, optional: true
  belongs_to :care_team, optional: true
  belongs_to :clinical_record, optional: true
  has_many :household_members, dependent: :destroy
  has_many :households, through: :household_members
  has_many :encounters, dependent: :destroy
  has_many :citizen_feature_snapshots, dependent: :nullify

  validates :municipality_id, presence: true
  validate :cpf_or_cns_present
  validate :cpf_format, if: -> { cpf.present? }

  private

  def cpf_format
    return if Cidadaobr::Cpf.valid?(cpf)

    errors.add(:cpf, :invalid)
  end

  def cpf_or_cns_present
    return if cpf.present? || cns.present?

    errors.add(:base, :cpf_or_cns_required)
  end
end
