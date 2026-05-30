# frozen_string_literal: true

class ReferenceDomain < ApplicationRecord
  SOURCES = %w[ufsc_dictionary reference_seed sigtap ledi_catalog fixture].freeze

  has_many :entries,
           class_name: "ReferenceDomainEntry",
           foreign_key: :domain_key,
           primary_key: :domain_key,
           inverse_of: false,
           dependent: :delete_all

  validates :domain_key, :source, presence: true
  validates :domain_key, uniqueness: true
  validates :source, inclusion: { in: SOURCES }
end
