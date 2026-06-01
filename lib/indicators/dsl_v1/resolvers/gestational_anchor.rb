# frozen_string_literal: true

module Indicators
  module DslV1
    module Resolvers
      module GestationalAnchor
        DUM_FIELD_ALIASES = %w[
          dumDaGestante dum_da_gestante dum dataUltimaMenstruacao data_ultima_menstruacao
        ].freeze

        DELIVERY_DATE_ALIASES = %w[
          dataParto data_parto dataDesfechoGestacao data_desfecho_gestacao
          dataOcorrenciaParto data_ocorrencia_parto
        ].freeze

        PUERPERIUM_DAYS = 42
        GESTATION_DAYS = 280
        GESTATIONAL_EVIDENCE_MEASURES = %w[consult visit blood_pressure anthropometry].freeze
        # C3 A–H: audit ended pregnancies within lookback (quadrimester), not only active at reference_date.
        RETROSPECTIVE_ACTIVE_ONLY_DEFAULT = false

        module_function

        def latest_dum(citizen, context, lookback_months: 15, active_only: true)
          ref = context.reference_date
          last_delivery = delivery_date(citizen, context, lookback_months: lookback_months)
          candidates = collect_dum_dates(citizen, context, lookback_months)
          current_cycle = if last_delivery
            candidates.select { |d| d > last_delivery }
          else
            candidates
          end

          active = current_cycle.select do |dum|
            ref >= dum && ref <= dum + GESTATION_DAYS.days + PUERPERIUM_DAYS.days
          end
          return active.max if active_only

          ended_pregnancy_dum = if last_delivery
            candidates.select { |d| d <= last_delivery && (last_delivery - d).to_i <= GESTATION_DAYS }.max
          end

          if active.any?
            unpaired_post_delivery = active.select do |dum|
              last_delivery &&
                dum > last_delivery &&
                delivery_for_dum(citizen, context, dum, lookback_months: lookback_months).nil?
            end
            real_active = active - unpaired_post_delivery
            return real_active.max if real_active.any?
            return ended_pregnancy_dum if ended_pregnancy_dum

            return active.max
          end
          return ended_pregnancy_dum if ended_pregnancy_dum

          candidates.select { |d| d <= ref }.max
        end

        def delivery_date(citizen, context, lookback_months: 15)
          ref = context.reference_date
          window_start = ref - lookback_months.months

          collect_delivery_dates(citizen, context, lookback_months)
            .select { |d| d <= ref && d >= window_start }
            .max
        end

        # Parto inferido de FAI (LEDI); pareado ao ciclo da DUM ancorada, não ao último parto global.
        def delivery_for_dum(citizen, context, dum, lookback_months: 15)
          return nil unless dum

          ref = context.reference_date
          window_start = ref - lookback_months.months

          collect_delivery_dates(citizen, context, lookback_months)
            .select do |d|
              d >= dum &&
                d <= ref &&
                d >= window_start &&
                (d - dum).to_i <= GESTATION_DAYS
            end
            .max
        end

        def gestational_week_at(dum, date)
          return nil unless dum && date
          return nil if date < dum

          ((date - dum).to_i / 7.0).floor
        end

        def records_in_gestational_window(
          citizen,
          context,
          record_types:,
          min_weeks:,
          max_weeks:,
          lookback_months: 15,
          active_only: true,
          exclude_after_delivery: false
        )
          dum = latest_dum(citizen, context, lookback_months: lookback_months, active_only: active_only)
          return [] unless dum

          delivery = exclude_after_delivery ? delivery_for_dum(citizen, context, dum, lookback_months: lookback_months) : nil
          window_start = context.reference_date - lookback_months.months
          ClinicalEvidence.clinical_records_for(citizen, record_types, since: window_start, context: context).select do |record|
            encounter_date = ClinicalEvidence.encounter_date_for(record, context)
            next false unless encounter_date
            next false if delivery && encounter_date >= delivery

            week = gestational_week_at(dum, encounter_date)
            week && week >= min_weeks && week <= max_weeks
          end
        end

        # Puerperium follow-ups must occur strictly after delivery (parto FAI on delivery day excluded).
        def records_in_puerperium_window(
          citizen,
          context,
          record_types:,
          days_after_delivery: PUERPERIUM_DAYS,
          lookback_months: 15,
          after_delivery: true
        )
          delivery = delivery_date(citizen, context, lookback_months: lookback_months)
          return [] unless delivery

          window_end = delivery + days_after_delivery.days
          window_start = delivery - 1.day

          ClinicalEvidence.clinical_records_for(
            citizen,
            record_types,
            since: window_start,
            context: context
          ).select do |record|
            encounter_date = ClinicalEvidence.encounter_date_for(record, context)
            next false unless encounter_date
            next false if encounter_date > window_end

            if after_delivery
              encounter_date > delivery
            else
              encounter_date >= delivery
            end
          end
        end

        def collect_dum_dates(citizen, context, lookback_months)
          window_start = context.reference_date - lookback_months.months
          dates = []

          ClinicalEvidence.clinical_records_for(
            citizen,
            %w[FAI],
            since: window_start,
            context: context
          ).each do |record|
            ClinicalEvidence.payloads_for_record(record, citizen).each do |payload|
              PayloadSections.each_section(payload, record_type: "FAI") do |section|
                DUM_FIELD_ALIASES.each do |field|
                  raw = PayloadSections.dig(section, field)
                  date = ClinicalEvidence.parse_date(raw)
                  dates << date if date
                end
              end
            end
          end

          dates.uniq
        end

        def collect_delivery_dates(citizen, context, lookback_months)
          window_start = context.reference_date - lookback_months.months
          dates = []

          ClinicalEvidence.clinical_records_for(
            citizen,
            %w[FAI],
            since: window_start,
            context: context
          ).each do |record|
            ClinicalEvidence.payloads_for_record(record, citizen).each do |payload|
              PayloadSections.each_section(payload, record_type: record.record_type) do |section|
                DELIVERY_DATE_ALIASES.each do |field|
                  raw = PayloadSections.dig(section, field)
                  date = ClinicalEvidence.parse_date(raw)
                  dates << date if date
                end
              end
            end
          end

          dates.uniq
        end
      end
    end
  end
end
