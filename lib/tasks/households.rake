# frozen_string_literal: true

namespace :households do
  desc "Backfill household locations from FCD clinical record payloads"
  task backfill_locations: :environment do
    updated = 0

    Municipality.find_each do |municipality|
      tenant = Cidadaobr::TenantScope.new(
        municipality_id: municipality.id,
        scope: "municipality",
        health_facility_id: nil,
        team_ids: [],
        citizen_id: nil
      )

      Cidadaobr::TenantContext.with(tenant) do
        Household.where(municipality_id: municipality.id, location: nil)
          .where.not(clinical_record_id: nil)
          .find_each do |household|
          clinical_record = household.clinical_record
          next unless clinical_record&.record_type == "FCD"

          location = Cidadaobr::GeoPoint.from_clinical_record_payload(clinical_record.payload_json)
          next unless location

          household.update!(location: location)
          updated += 1
        end
      end
    end

    puts "Updated #{updated} household locations."
  end
end
