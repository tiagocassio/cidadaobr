# frozen_string_literal: true

class CitizenAccount < ApplicationRecord
  has_secure_password

  belongs_to :municipality
  belongs_to :citizen

  validates :municipality_id, :citizen_id, :cpf, presence: true
  validates :cpf, uniqueness: { scope: :municipality_id }
  validates :citizen_id, uniqueness: true
end
