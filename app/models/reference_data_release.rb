# frozen_string_literal: true

class ReferenceDataRelease < ApplicationRecord
  validates :release_key, :ledi_version, :checksum, :published_at, presence: true
  validates :release_key, uniqueness: true
end
