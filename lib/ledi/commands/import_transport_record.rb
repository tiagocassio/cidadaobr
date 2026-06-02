# frozen_string_literal: true

module Ledi
  class ImportTransportRecord < ApplicationCommand
    def initialize(payload_binary:, origin_health_facility_id: nil)
      @payload_binary = payload_binary
      @origin_health_facility_id = origin_health_facility_id
    end

    def call
      tenant = Cidadaobr::TenantContext.current_or_raise!
      deserialized = TransportDeserializer.call(@payload_binary)
      ledi_config = Rails.application.config.ledi
      serialized_uuid = deserialized.header.fetch(:uuid_dado_serializado)

      existing = TransportRecord.find_by(municipality_id: tenant.municipality_id, serialized_uuid: serialized_uuid)
      if existing
        return refresh_existing!(existing, deserialized, tenant) if existing.payload_binary != @payload_binary

        return {
          transport_record: existing,
          clinical_record: existing.clinical_record,
          reimported: true
        }
      end

      write_transaction do
        facility = resolve_facility(deserialized.header[:cnes_dado_serializado], tenant)
        care_team = resolve_care_team(deserialized.header[:ine_dado_serializado], facility, tenant)
        ibge_code = resolve_ibge_code(deserialized.header, tenant)

        transport_record = TransportRecord.create!(
          municipality_id: tenant.municipality_id,
          health_facility_id: facility&.id || tenant.health_facility_id,
          care_team_id: care_team&.id,
          origin_health_facility_id: @origin_health_facility_id || facility&.id,
          serialized_uuid: serialized_uuid,
          serialized_type: deserialized.serialized_type,
          cnes: deserialized.header.fetch(:cnes_dado_serializado),
          ibge_code: ibge_code,
          ine: deserialized.header[:ine_dado_serializado],
          batch_number: deserialized.header[:num_lote],
          payload_binary: @payload_binary,
          ledi_version: ledi_config.fetch(:version),
          status: "draft"
        )

        clinical_record = create_clinical_record!(
          transport_record: transport_record,
          deserialized: deserialized,
          tenant: tenant,
          facility: facility,
          care_team: care_team
        )

        emit_imported_event!(clinical_record, transport_record, care_team)

        { transport_record: transport_record, clinical_record: clinical_record, reimported: false }
      end
    end

    private

    def refresh_existing!(existing, deserialized, tenant)
      ensure_refreshable!(existing)
      previous_transport_status = existing.status

      write_transaction do
        facility = resolve_facility(deserialized.header[:cnes_dado_serializado], tenant)
        care_team = resolve_care_team(deserialized.header[:ine_dado_serializado], facility, tenant)
        ibge_code = resolve_ibge_code(deserialized.header, tenant)

        existing.update!(
          health_facility_id: facility&.id || tenant.health_facility_id,
          care_team_id: care_team&.id,
          serialized_type: deserialized.serialized_type,
          cnes: deserialized.header.fetch(:cnes_dado_serializado),
          ibge_code: ibge_code,
          ine: deserialized.header[:ine_dado_serializado],
          batch_number: deserialized.header[:num_lote],
          payload_binary: @payload_binary,
          ledi_version: Rails.application.config.ledi.fetch(:version),
          status: "draft"
        )

        clinical_record = existing.clinical_record
        payload = deserialized.payload
        record_uuid = PayloadExtractors.record_uuid(payload, record_type: deserialized.record_type) ||
          existing.serialized_uuid

        clinical_record.clinical_record_items.destroy_all
        clinical_record.update!(
          health_facility_id: facility&.id || tenant.health_facility_id,
          care_team_id: care_team&.id,
          record_type: deserialized.record_type,
          record_uuid: record_uuid,
          originator_record_uuid: PayloadExtractors.originator_record_uuid(payload, record_type: deserialized.record_type),
          payload_json: payload,
          payload_schema_version: Rails.application.config.ledi.fetch(:version),
          cnes: existing.cnes,
          ibge_code: ibge_code,
          encounter_at: PayloadExtractors.encounter_at(payload),
          professional_cns: PayloadExtractors.professional_cns(payload),
          validation_status: "pending",
          validation_errors: []
        )

        create_nested_items!(clinical_record, payload, deserialized.record_type)

        emit_imported_event!(
          clinical_record,
          existing,
          care_team,
          refreshed: true,
          previous_transport_status: previous_transport_status
        )

        {
          transport_record: existing,
          clinical_record: clinical_record,
          reimported: true,
          refreshed: true
        }
      end
    end

    def ensure_refreshable!(existing)
      # Pre-batch refresh: draft/validated without batch assignment may be corrected in place; batched/submitted records require EPIC-09 flows.
      return if existing.ledi_batch_id.blank? && existing.status.in?(%w[draft validated])

      raise Errors::ImmutableTransportRecordError,
            "Transport record #{existing.serialized_uuid} cannot be refreshed after batch submission"
    end

    def emit_imported_event!(clinical_record, transport_record, care_team, refreshed: false, previous_transport_status: nil)
      payload = {
        clinical_record_id: clinical_record.id,
        transport_record_id: transport_record.id,
        record_type: clinical_record.record_type,
        record_uuid: clinical_record.record_uuid
      }
      if refreshed
        payload[:refreshed] = true
        payload[:previous_transport_status] = previous_transport_status if previous_transport_status.present?
      end

      RecordPlatformEvent.call(
        event_type: Cidadaobr::KafkaTopics::CLINICAL_RECORD_IMPORTED,
        aggregate_type: "ClinicalRecord",
        aggregate_id: clinical_record.id,
        payload: payload,
        care_team_id: care_team&.id
      )
    end

    def resolve_ibge_code(header, tenant)
      header[:cod_ibge].presence || Municipality.find(tenant.municipality_id).ibge_code
    end

    def resolve_care_team(ine, facility, tenant)
      return if ine.blank?

      scope = CareTeam.where(municipality_id: tenant.municipality_id, ine: ine)
      scope = scope.where(health_facility_id: facility.id) if facility

      scope.sole
    rescue ActiveRecord::RecordNotFound
      raise Errors::UnknownCareTeamError, "Unknown care team INE #{ine}"
    rescue ActiveRecord::SoleRecordExceeded
      raise Errors::AmbiguousTeamScopeError, "Ambiguous care team INE #{ine} for municipality"
    end

    def create_clinical_record!(transport_record:, deserialized:, tenant:, facility:, care_team:)
      payload = deserialized.payload
      record_uuid = PayloadExtractors.record_uuid(payload, record_type: deserialized.record_type) ||
        transport_record.serialized_uuid

      clinical_record = ClinicalRecord.create!(
        municipality_id: tenant.municipality_id,
        health_facility_id: facility&.id || tenant.health_facility_id,
        care_team_id: care_team&.id,
        transport_record: transport_record,
        record_type: deserialized.record_type,
        record_uuid: record_uuid,
        originator_record_uuid: PayloadExtractors.originator_record_uuid(payload, record_type: deserialized.record_type),
        payload_json: payload,
        payload_schema_version: Rails.application.config.ledi.fetch(:version),
        cnes: transport_record.cnes,
        ibge_code: transport_record.ibge_code,
        encounter_at: PayloadExtractors.encounter_at(payload),
        professional_cns: PayloadExtractors.professional_cns(payload),
        validation_status: "pending",
        validation_errors: []
      )

      create_nested_items!(clinical_record, payload, deserialized.record_type)
      clinical_record
    end

    def create_nested_items!(clinical_record, payload, record_type)
      items_key = nested_items_key(record_type)
      return if items_key.blank?

      Array(payload[items_key]).each_with_index do |item_payload, index|
        identifiers = PayloadExtractors.citizen_identifiers(item_payload)
        clinical_record.clinical_record_items.create!(
          sequence: index,
          payload_json: item_payload,
          citizen_cpf: identifiers[:cpf],
          citizen_cns: identifiers[:cns]
        )
      end
    end

    def nested_items_key(record_type)
      {
        "FAI" => "atendimentos_individuais",
        "FAO" => "atendimentos_odontologicos",
        "FP" => "atendimentos_procedimentos",
        "FV" => "vacinacoes",
        "FVD" => "visitas_domiciliares",
        "FAD" => "atendimentos_domiciliares"
      }[record_type]
    end

    def resolve_facility(cnes, tenant)
      return if cnes.blank?

      HealthFacility.find_by(municipality_id: tenant.municipality_id, cnes: cnes)
    end
  end
end
