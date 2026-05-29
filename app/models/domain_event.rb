# frozen_string_literal: true

class DomainEvent < ApplicationRecord
  validates :municipality_id, :aggregate_type, :aggregate_id, :event_type, :occurred_at, :version, presence: true

  before_destroy { raise ActiveRecord::ReadOnlyRecord, "DomainEvent records are append-only" }
  before_update { raise ActiveRecord::ReadOnlyRecord, "DomainEvent records are append-only" }

  class << self
    def append!(attributes)
      tenant = Cidadaobr::TenantContext.current_or_raise!

      create!(
        attributes.merge(
          municipality_id: attributes.fetch(:municipality_id, tenant.municipality_id),
          health_facility_id: attributes[:health_facility_id] || tenant.health_facility_id,
          care_team_id: attributes[:care_team_id]
        )
      )
    end
  end

  def readonly?
    persisted?
  end
end
