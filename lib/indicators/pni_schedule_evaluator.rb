# frozen_string_literal: true

module Indicators
  module PniScheduleEvaluator
    Result = Struct.new(:compliant, :missing, :release_key, :evaluable, keyword_init: true)

    module_function

    def evaluate(citizen:, reference_date:, age_group: "child", scope_max_age_days: 730, context: nil)
      birth = citizen.birth_date
      return empty_result unless birth

      age_days = age_in_days(birth, reference_date)
      return empty_result if age_days.negative? || age_days > scope_max_age_days

      entries = schedule_entries(reference_date: reference_date, age_group: age_group, context: context)
      return cache_evaluate_result(context, age_group, scope_max_age_days, reference_date, unevaluable_result) if entries.empty?

      fv_within_months = (scope_max_age_days / 30.4375).ceil
      # C2.E: doses stay required after max_age_days closes (missed window still counts as gap).
      required = entries.select { |entry| entry.min_age_days <= age_days }
      immunizations = immunizations_for(citizen, context)

      missing = required.reject do |entry|
        dose_satisfied?(
          entry,
          birth: birth,
          reference_date: reference_date,
          immunizations: immunizations,
          context: context,
          fv_within_months: fv_within_months
        )
      end

      cache_evaluate_result(
        context,
        age_group,
        scope_max_age_days,
        reference_date,
        Result.new(
          compliant: missing.empty?,
          missing: missing.map { |entry| missing_entry_payload(entry) },
          release_key: PniScheduleEntry.latest_release_key_for(reference_date: reference_date, age_group: age_group),
          evaluable: true
        )
      )
    end

    def required_immunobiologicals(age_months, reference_date: Date.current, age_group: "child")
      age_days = (age_months * 30.4375).floor
      entries = schedule_entries(reference_date: reference_date, age_group: age_group)
      entries
        .select { |entry| entry.min_age_days <= age_days }
        .map { |entry| entry.immunobiological_name }
        .uniq
    end

    def schedule_entries(reference_date:, age_group:, context: nil)
      if context
        context.cache[:pni_schedule_entries] ||= {}
        cache_key = [ reference_date, age_group ]
        return context.cache[:pni_schedule_entries][cache_key] if context.cache[:pni_schedule_entries].key?(cache_key)

        entries = load_schedule_entries(reference_date: reference_date, age_group: age_group)
        context.cache[:pni_schedule_entries][cache_key] = entries
        entries
      else
        load_schedule_entries(reference_date: reference_date, age_group: age_group)
      end
    end

    def load_schedule_entries(reference_date:, age_group:)
      PniScheduleEntry.effective_on(reference_date).for_age_group(age_group).order(:min_age_days, :immunobiological_code, :dose_code).to_a
    end

    def calendar_loaded?(reference_date:, age_group: "child", context: nil)
      scope = PniScheduleEntry.effective_on(reference_date).for_age_group(age_group)
      return scope.exists? unless context

      context.cache[:pni_calendar_loaded] ||= {}
      cache_key = [ reference_date, age_group ]
      return context.cache[:pni_calendar_loaded][cache_key] if context.cache[:pni_calendar_loaded].key?(cache_key)

      loaded = scope.exists?
      context.cache[:pni_calendar_loaded][cache_key] = loaded
      loaded
    end

    def cache_evaluate_result(context, age_group, scope_max_age_days, reference_date, result)
      return result unless context

      context.cache[:pni_evaluate] ||= {}
      context.cache[:pni_evaluate][[ age_group, scope_max_age_days, reference_date ]] = result
      result
    end

    def dose_satisfied?(entry, birth:, reference_date:, immunizations:, context: nil, fv_within_months: 24)
      if immunizations.any? { |record| immunization_matches?(record, entry, birth: birth, reference_date: reference_date) }
        return true
      end

      return false unless context

      fv_record_satisfied?(entry, birth: birth, reference_date: reference_date, context: context, within_months: fv_within_months)
    end

    def fv_record_satisfied?(entry, birth:, reference_date:, context:, within_months:)
      DslV1::Resolvers::ClinicalEvidence.records_in_window(context, %w[FV], within_months).any? do |record|
        encounter_date = DslV1::Resolvers::ClinicalEvidence.encounter_date_for(record, context)
        next false unless encounter_date
        next false if encounter_date > reference_date

        applied_age_days = age_in_days(birth, encounter_date)
        next false unless applied_age_days >= entry.min_age_days && applied_age_days <= entry.max_age_days

        DslV1::Resolvers::ClinicalEvidence.payloads_for_record(record, context.citizen).any? do |payload|
          DslV1::Resolvers::ClinicalEvidence.vaccination_dose_match?(
            payload,
            immunobiological_code: entry.immunobiological_code,
            dose_code: entry.dose_code,
            aliases: entry.aliases
          )
        end
      end
    end

    def immunization_matches?(record, entry, birth:, reference_date:)
      return false unless PniCodeNormalizer.normalize_code(record.vaccine_code) == PniCodeNormalizer.normalize_code(entry.immunobiological_code)
      return false unless PniCodeNormalizer.normalize_dose_code(record.dose_label) == PniCodeNormalizer.normalize_dose_code(entry.dose_code)

      applied_on = record.applied_on
      return false unless applied_on
      return false if applied_on > reference_date

      applied_age_days = age_in_days(birth, applied_on)
      applied_age_days >= entry.min_age_days && applied_age_days <= entry.max_age_days
    end

    def immunizations_for(citizen, context)
      if context
        context.cache[:citizen_immunizations] ||= {}
        context.cache[:citizen_immunizations][citizen.id] ||= CitizenImmunizationRecord
          .where(municipality_id: citizen.municipality_id, citizen_id: citizen.id)
          .to_a
      else
        CitizenImmunizationRecord.where(municipality_id: citizen.municipality_id, citizen_id: citizen.id).to_a
      end
    end

    def missing_entry_payload(entry)
      {
        immunobiological_code: entry.immunobiological_code,
        immunobiological_name: entry.immunobiological_name,
        dose_code: entry.dose_code,
        dose_label: entry.dose_label,
        min_age_days: entry.min_age_days,
        max_age_days: entry.max_age_days
      }
    end

    def empty_result
      unevaluable_result
    end

    def unevaluable_result
      Result.new(
        compliant: false,
        missing: [],
        release_key: nil,
        evaluable: false
      )
    end

    def age_in_days(birth_date, reference_date)
      (reference_date - birth_date).to_i
    end
  end
end
