# frozen_string_literal: true

module PniCalendarHelpers
  def sync_pni_calendar!(export_json: false, publish_release: false)
    CommandBus.dispatch(
      Reference::Commands::SyncPniCalendar,
      export_json: export_json,
      publish_release: publish_release
    )
  end

  def seed_pni_compliant_immunizations!(citizen:, reference_date: Date.current)
    birth = citizen.birth_date
    return unless birth

    age_days = (reference_date - birth).to_i
    PniScheduleEntry.effective_on(reference_date).for_age_group("child").each do |entry|
      next unless entry.min_age_days <= age_days

      applied_on = birth + [ entry.min_age_days + 1, entry.max_age_days ].min.days
      CitizenImmunizationRecord.find_or_initialize_by(
        municipality_id: citizen.municipality_id,
        citizen_id: citizen.id,
        vaccine_code: entry.immunobiological_code,
        dose_label: entry.dose_code
      ).tap do |record|
        record.vaccine_name = entry.immunobiological_name
        record.applied_on = applied_on
        record.source = "spec_fixture"
        record.save!
      end
    end
  end
end

RSpec.configure do |config|
  config.include PniCalendarHelpers
end
