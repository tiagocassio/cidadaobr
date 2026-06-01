# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::DslV1::Resolvers::GestationalAnchor do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }
  let(:reference_date) { Date.new(2026, 5, 30) }
  let(:context) { Indicators::DslV1::Context.new(citizen: citizen, reference_date: reference_date) }

  def persist_clinical_record!(citizen:, record_type:, payload_json:, encounter_at: Time.zone.now)
    transport = TransportRecord.create!(
      municipality: municipality,
      health_facility: facility,
      serialized_uuid: SecureRandom.uuid,
      serialized_type: record_type,
      cnes: facility.cnes,
      ibge_code: municipality.ibge_code,
      payload_binary: "\x00",
      ledi_version: Rails.application.config.ledi.fetch(:version),
      status: "validated"
    )
    record = ClinicalRecord.create!(
      municipality: municipality,
      health_facility: facility,
      care_team: team,
      transport_record: transport,
      record_type: record_type,
      record_uuid: SecureRandom.uuid,
      payload_schema_version: Rails.application.config.ledi.fetch(:version),
      validation_status: "valid",
      validation_errors: [],
      payload_json: payload_json,
      encounter_at: encounter_at
    )
    Encounter.create!(
      municipality: municipality,
      health_facility: facility,
      care_team: team,
      citizen: citizen,
      clinical_record: record,
      record_type: record_type,
      encounter_at: encounter_at
    )
    record
  end

  def persist_fai!(citizen:, payload_json:, encounter_at:)
    persist_clinical_record!(
      citizen: citizen,
      record_type: "FAI",
      payload_json: payload_json,
      encounter_at: encounter_at
    )
  end

  describe ".delivery_for_dum" do
    let(:citizen) do
      with_tenant(membership) do
        create(:citizen, municipality: municipality, health_facility: facility, care_team: team, sex: "female")
      end
    end

    it "returns delivery paired to the anchored DUM cycle, not an earlier pregnancy" do
      prior_delivery = reference_date - 14.months
      prior_dum = prior_delivery - 280.days
      current_dum = reference_date - 4.months
      current_delivery = current_dum + 100.days # on or before reference_date

      with_tenant(membership) do
        persist_fai!(citizen: citizen, payload_json: { "dumDaGestante" => prior_dum.iso8601 }, encounter_at: prior_dum)
        persist_fai!(citizen: citizen, payload_json: { "dataParto" => prior_delivery.iso8601 }, encounter_at: prior_delivery)
        persist_fai!(citizen: citizen, payload_json: { "dumDaGestante" => current_dum.iso8601 }, encounter_at: current_dum)
        persist_fai!(citizen: citizen, payload_json: { "dataParto" => current_delivery.iso8601 }, encounter_at: current_delivery)
      end

      with_tenant(membership) do
        expect(described_class.delivery_for_dum(citizen.reload, context, current_dum)).to eq(current_delivery)
        expect(described_class.delivery_for_dum(citizen.reload, context, prior_dum)).to eq(prior_delivery)
      end
    end

    it "returns nil when no delivery is recorded for the DUM cycle" do
      current_dum = reference_date - 4.months

      with_tenant(membership) do
        persist_fai!(citizen: citizen, payload_json: { "dumDaGestante" => current_dum.iso8601 }, encounter_at: current_dum)
      end

      with_tenant(membership) do
        expect(described_class.delivery_for_dum(citizen.reload, context, current_dum)).to be_nil
      end
    end
  end

  describe ".latest_dum" do
    let(:citizen) do
      with_tenant(membership) do
        create(:citizen, municipality: municipality, health_facility: facility, care_team: team, sex: "female")
      end
    end

    it "anchors to DUM after the most recent delivery" do
      prior_delivery = reference_date - 8.months
      current_dum = reference_date - 3.months

      with_tenant(membership) do
        persist_fai!(citizen: citizen, payload_json: { "dumDaGestante" => (prior_delivery - 9.months).iso8601 }, encounter_at: prior_delivery - 9.months)
        persist_fai!(citizen: citizen, payload_json: { "dataParto" => prior_delivery.iso8601 }, encounter_at: prior_delivery)
        persist_fai!(citizen: citizen, payload_json: { "dumDaGestante" => current_dum.iso8601 }, encounter_at: current_dum)
      end

      with_tenant(membership) do
        expect(described_class.latest_dum(citizen.reload, context)).to eq(current_dum)
      end
    end

    it "returns nil when reference_date is outside pregnancy and puerperium" do
      ended_pregnancy_dum = reference_date - 2.years
      delivery = ended_pregnancy_dum + 280.days

      with_tenant(membership) do
        persist_fai!(citizen: citizen, payload_json: { "dumDaGestante" => ended_pregnancy_dum.iso8601 }, encounter_at: ended_pregnancy_dum)
        persist_fai!(citizen: citizen, payload_json: { "dataParto" => delivery.iso8601 }, encounter_at: delivery)
      end

      with_tenant(membership) do
        expect(described_class.latest_dum(citizen.reload, context)).to be_nil
        expect(described_class.latest_dum(citizen.reload, context, active_only: false)).to be_nil
      end
    end

    it "returns lookback DUM with active_only false when pregnancy ended without delivery record" do
      stale_dum = reference_date - 11.months

      with_tenant(membership) do
        persist_fai!(citizen: citizen, payload_json: { "dumDaGestante" => stale_dum.iso8601 }, encounter_at: stale_dum)
      end

      with_tenant(membership) do
        expect(described_class.latest_dum(citizen.reload, context)).to be_nil
        expect(described_class.latest_dum(citizen.reload, context, active_only: false)).to eq(stale_dum)
      end
    end

    it "anchors active_only false to the most recent ended pregnancy in lookback" do
      older_delivery = reference_date - 13.months
      older_dum = older_delivery - 280.days
      recent_delivery = reference_date - 2.months
      recent_dum = recent_delivery - 280.days

      with_tenant(membership) do
        persist_fai!(citizen: citizen, payload_json: { "dumDaGestante" => older_dum.iso8601 }, encounter_at: older_dum)
        persist_fai!(citizen: citizen, payload_json: { "dataParto" => older_delivery.iso8601 }, encounter_at: older_delivery)
        persist_fai!(citizen: citizen, payload_json: { "dumDaGestante" => recent_dum.iso8601 }, encounter_at: recent_dum)
        persist_fai!(citizen: citizen, payload_json: { "dataParto" => recent_delivery.iso8601 }, encounter_at: recent_delivery)
      end

      with_tenant(membership) do
        expect(described_class.latest_dum(citizen.reload, context, active_only: false)).to eq(recent_dum)
      end
    end

    it "ignores post-delivery DUM without parto when an ended pregnancy is known" do
      recent_delivery = reference_date - 2.months
      recent_dum = recent_delivery - 280.days
      phantom_dum = reference_date - 1.month

      with_tenant(membership) do
        persist_fai!(citizen: citizen, payload_json: { "dumDaGestante" => recent_dum.iso8601 }, encounter_at: recent_dum)
        persist_fai!(citizen: citizen, payload_json: { "dataParto" => recent_delivery.iso8601 }, encounter_at: recent_delivery)
        persist_fai!(citizen: citizen, payload_json: { "dumDaGestante" => phantom_dum.iso8601 }, encounter_at: phantom_dum)
      end

      with_tenant(membership) do
        expect(described_class.latest_dum(citizen.reload, context, active_only: false)).to eq(recent_dum)
      end
    end
  end

  describe ".delivery_date" do
    let(:citizen) do
      with_tenant(membership) do
        create(:citizen, municipality: municipality, health_facility: facility, care_team: team, sex: "female")
      end
    end

    it "returns the most recent delivery on or before reference_date" do
      old_delivery = reference_date - 10.months
      recent_delivery = reference_date - 3.weeks

      with_tenant(membership) do
        persist_fai!(citizen: citizen, payload_json: { "dataParto" => old_delivery.iso8601 }, encounter_at: old_delivery)
        persist_fai!(citizen: citizen, payload_json: { "dataParto" => recent_delivery.iso8601 }, encounter_at: recent_delivery)
      end

      with_tenant(membership) do
        expect(described_class.delivery_date(citizen.reload, context)).to eq(recent_delivery)
      end
    end
  end

  describe ".records_in_puerperium_window" do
    let(:citizen) do
      with_tenant(membership) do
        create(:citizen, municipality: municipality, health_facility: facility, care_team: team, sex: "female")
      end
    end

    it "excludes parto FAI on delivery day when after_delivery is true" do
      delivery = reference_date - 2.weeks

      with_tenant(membership) do
        persist_fai!(citizen: citizen, payload_json: { "dataParto" => delivery.iso8601 }, encounter_at: delivery)
        persist_fai!(citizen: citizen, payload_json: {}, encounter_at: delivery + 5.days)
      end

      with_tenant(membership) do
        records = described_class.records_in_puerperium_window(
          citizen.reload,
          context,
          record_types: %w[FAI],
          after_delivery: true
        )

        expect(records.size).to eq(1)
        expect(Indicators::DslV1::Resolvers::ClinicalEvidence.encounter_date_for(records.first, context)).to eq(delivery + 5.days)
      end
    end
  end

  describe ".records_in_gestational_window" do
    let(:citizen) do
      with_tenant(membership) do
        create(:citizen, municipality: municipality, health_facility: facility, care_team: team, sex: "female")
      end
    end

    it "excludes encounters after delivery when exclude_after_delivery is true" do
      dum = reference_date - 10.months
      delivery = dum + 280.days

      with_tenant(membership) do
        persist_fai!(citizen: citizen, payload_json: { "dumDaGestante" => dum.iso8601 }, encounter_at: dum + 8.weeks)
        persist_fai!(citizen: citizen, payload_json: { "dataParto" => delivery.iso8601 }, encounter_at: delivery)
        persist_fai!(citizen: citizen, payload_json: {}, encounter_at: delivery + 5.days)
      end

      with_tenant(membership) do
        records = described_class.records_in_gestational_window(
          citizen.reload,
          context,
          record_types: %w[FAI],
          min_weeks: 0,
          max_weeks: 42,
          active_only: false,
          exclude_after_delivery: true
        )

        expect(records.size).to eq(1)
        expect(Indicators::DslV1::Resolvers::ClinicalEvidence.encounter_date_for(records.first, context)).to eq(dum + 8.weeks)
      end
    end
  end
end
