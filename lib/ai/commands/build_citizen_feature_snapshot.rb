# frozen_string_literal: true

module Ai
  module Commands
    class BuildCitizenFeatureSnapshot < ApplicationCommand
      LEGACY_SOURCE_META_KEY = "_source"

      def initialize(clinical_record_id:, computed_at: nil)
        @clinical_record_id = clinical_record_id
        @computed_at = computed_at
      end

      def call
        clinical_record = ClinicalRecord.find_by!(id: @clinical_record_id)
        # v1 defensive skip — see ADR-0007 (clinical.record.persisted is normally post-validation).
        unless clinical_record.validation_status == "valid"
          ActiveSupport::Notifications.instrument(
            "kafka.feature_snapshot.validation_skipped",
            clinical_record_id: clinical_record.id,
            validation_status: clinical_record.validation_status
          )
          return
        end

        if (unchanged_snapshot = unchanged_snapshot_for(clinical_record))
          return unchanged_snapshot
        end

        # Caller must project citizen first when needed (ClinicalRecordPersistedConsumer does).
        features = FeatureExtractor.call(clinical_record: clinical_record)
        citizen = resolve_citizen(clinical_record)

        write_transaction do
          snapshot, changed = upsert_snapshot!(
            clinical_record: clinical_record,
            citizen: citizen,
            features: features
          )
          emit_fact_extracted!(clinical_record: clinical_record, citizen: citizen, snapshot: snapshot) if changed
          snapshot
        end
      end

      private

      def upsert_snapshot!(clinical_record:, citizen:, features:)
        snapshot = CitizenFeatureSnapshot.find_or_initialize_by(
          clinical_record_id: clinical_record.id,
          feature_schema_version: CitizenFeatureSnapshot::FEATURE_SCHEMA_VERSION
        )
        was_new = snapshot.new_record?
        previous_features = snapshot.features if snapshot.persisted?
        previous_citizen_id = snapshot.citizen_id if snapshot.persisted?
        normalized_features = features.deep_stringify_keys
        digest = payload_digest(clinical_record)

        changed = was_new ||
          features_changed?(previous_features, normalized_features) ||
          previous_citizen_id != citizen&.id ||
          snapshot.source_payload_digest != digest

        if changed
          snapshot.assign_attributes(
            municipality_id: clinical_record.municipality_id,
            citizen_id: citizen&.id,
            record_type: clinical_record.record_type,
            features: normalized_features,
            source_payload_digest: digest,
            computed_at: @computed_at || clinical_record.updated_at
          )
          snapshot.save!
        end

        [ snapshot, changed ]
      end

      def unchanged_snapshot_for(clinical_record)
        snapshot = CitizenFeatureSnapshot.find_by(
          clinical_record_id: clinical_record.id,
          feature_schema_version: CitizenFeatureSnapshot::FEATURE_SCHEMA_VERSION
        )
        return unless snapshot&.persisted?
        return if clinical_record.updated_at > snapshot.updated_at

        citizen = resolve_citizen(clinical_record)
        return if snapshot.citizen_id != citizen&.id

        stored_digest = snapshot.source_payload_digest.presence || legacy_payload_digest(snapshot)
        return if stored_digest.present? && stored_digest != payload_digest(clinical_record)

        snapshot
      end

      def legacy_payload_digest(snapshot)
        snapshot.features.dig(LEGACY_SOURCE_META_KEY, "payload_digest")
      end

      def payload_digest(clinical_record)
        Digest::SHA256.hexdigest(
          [
            FeatureExtractor::LOGIC_VERSION,
            ActiveSupport::JSON.encode(clinical_record.payload_json || {})
          ].join("|")
        )
      end

      def features_changed?(before, after)
        normalize_features_for_compare(strip_legacy_source_meta(before)) !=
          normalize_features_for_compare(strip_legacy_source_meta(after))
      end

      def strip_legacy_source_meta(features)
        return {} if features.blank?

        features.except(LEGACY_SOURCE_META_KEY)
      end

      def normalize_features_for_compare(value)
        case value
        when Hash
          value.deep_stringify_keys.transform_values { normalize_features_for_compare(_1) }.sort.to_h
        when Array
          value.map { normalize_features_for_compare(_1) }.sort_by { |element| array_sort_key(element) }
        when Integer
          return "true" if value == 1
          return "false" if value == 0

          value.to_s
        when Float
          return "true" if value == 1.0
          return "false" if value == 0.0
          return value.to_i.to_s if value == value.to_i

          value.to_s
        when TrueClass, FalseClass
          value ? "true" : "false"
        when String
          downcased = value.downcase
          return "true" if downcased.in?(%w[true t yes 1])
          return "false" if downcased.in?(%w[false f no 0])

          value
        else
          value
        end
      end

      def array_sort_key(value)
        case value
        when Hash
          value.sort.to_h.to_json
        when Array
          value.map { array_sort_key(_1) }.to_json
        else
          value.to_s
        end
      end

      def resolve_citizen(clinical_record)
        clinical_record.citizen ||
          clinical_record.encounters.where.not(citizen_id: nil).order(encounter_at: :desc).first&.citizen ||
          lookup_citizen_from_payload(clinical_record)
      end

      def lookup_citizen_from_payload(clinical_record)
        identifiers = Ledi::PayloadExtractors.citizen_identifiers(clinical_record.payload_json)
        if identifiers[:cpf].present?
          Citizen.find_by(municipality_id: clinical_record.municipality_id, cpf: identifiers[:cpf])
        elsif identifiers[:cns].present?
          Citizen.find_by(municipality_id: clinical_record.municipality_id, cns: identifiers[:cns])
        end
      end

      # ADR-0007: event carries ids/metadata only; features live in citizen_feature_snapshots.
      def emit_fact_extracted!(clinical_record:, citizen:, snapshot:)
        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::CLINICAL_FACT_EXTRACTED,
          aggregate_type: "CitizenFeatureSnapshot",
          aggregate_id: snapshot.id,
          payload: {
            citizen_feature_snapshot_id: snapshot.id,
            clinical_record_id: clinical_record.id,
            citizen_id: citizen&.id,
            record_type: clinical_record.record_type,
            feature_schema_version: snapshot.feature_schema_version
          },
          care_team_id: clinical_record.care_team_id
        )
      end
    end
  end
end
