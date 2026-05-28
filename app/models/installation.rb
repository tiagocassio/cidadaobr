# frozen_string_literal: true

class Installation < ApplicationRecord
  belongs_to :municipality

  validates :municipality_id, :counter_key, :installation_uuid, :tax_id, :legal_name, presence: true
  validates :installation_uuid, uniqueness: { scope: :municipality_id }
  validates :counter_key, uniqueness: { scope: :municipality_id }
end
