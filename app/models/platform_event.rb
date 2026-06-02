# frozen_string_literal: true

class PlatformEvent < ApplicationRecord
  validates :aggregate_type, :aggregate_id, :event_type, :occurred_at, :version, presence: true

  before_destroy { raise ActiveRecord::ReadOnlyRecord, "PlatformEvent records are append-only" }
  before_update { raise ActiveRecord::ReadOnlyRecord, "PlatformEvent records are append-only" }

  class << self
    def append!(attributes)
      create!(attributes)
    end
  end

  def readonly?
    persisted?
  end
end
