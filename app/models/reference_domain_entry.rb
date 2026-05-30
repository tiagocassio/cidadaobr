# frozen_string_literal: true

class ReferenceDomainEntry < ApplicationRecord
  validates :domain_key, :code, :label, presence: true
  validates :code, uniqueness: { scope: :domain_key }

  scope :active, -> { where(active: true) }
  scope :for_domain, ->(key) { where(domain_key: key) }
end
