# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::Commands::BuildCitizenFeatureSnapshot do
  let(:municipality) { create(:municipality, ibge_code: "3550308") }
  let(:facility) { create(:health_facility, municipality: municipality, cnes: "2000001") }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality")
  end

  before do
    load Rails.root.join("db/seeds/ledi_catalog.rb")
  end

  def import_and_validate_fci!
    with_tenant(membership) do
      clinical_record = Ledi::ImportTransportRecord.call(
        payload_binary: LediFixtures.fci_binary(cnes: facility.cnes, ibge: municipality.ibge_code)
      )[:clinical_record]
      Ledi::ValidateClinicalRecord.call(clinical_record_id: clinical_record.id)
      Ledi::ProjectionRunner.call(clinical_record: clinical_record.reload)
      clinical_record.reload
    end
  end

  it "persists a feature snapshot and emits clinical-fact-extracted" do
    clinical_record = import_and_validate_fci!

    expect do
      with_tenant(membership) do
        CommandBus.dispatch(described_class, clinical_record_id: clinical_record.id)
      end
    end.to change { with_tenant(membership) { CitizenFeatureSnapshot.count } }.by(1)
      .and change {
        with_tenant(membership) do
          DomainEvent.where(event_type: Cidadaobr::KafkaTopics::CLINICAL_FACT_EXTRACTED).count
        end
      }.by(1)

    snapshot = with_tenant(membership) { CitizenFeatureSnapshot.last }
    expect(snapshot.clinical_record_id).to eq(clinical_record.id)
    expect(snapshot.citizen_id).to be_present
    expect(snapshot.features["record_type"]).to eq("FCI")
    expect(snapshot.feature_schema_version).to eq("v1")
  end

  it "is idempotent for the same clinical record" do
    clinical_record = import_and_validate_fci!

    with_tenant(membership) do
      CommandBus.dispatch(described_class, clinical_record_id: clinical_record.id)
      CommandBus.dispatch(described_class, clinical_record_id: clinical_record.id)
    end

    expect(with_tenant(membership) { CitizenFeatureSnapshot.count }).to eq(1)
    expect(
      with_tenant(membership) do
        DomainEvent.where(event_type: Cidadaobr::KafkaTopics::CLINICAL_FACT_EXTRACTED).count
      end
    ).to eq(1)
  end

  it "normalizes scalar types when comparing features" do
    command = described_class.new(clinical_record_id: SecureRandom.uuid)

    expect(command.send(:features_changed?, { "citizen" => { "sex" => 2 } }, { "citizen" => { "sex" => "2" } }))
      .to be(false)
    expect(command.send(:features_changed?, { "citizen" => { "sex" => 2 } }, { "citizen" => { "sex" => 3 } }))
      .to be(true)
    expect(command.send(:features_changed?, { "flag" => true }, { "flag" => "true" })).to be(false)
    expect(command.send(:features_changed?, { "flag" => 1 }, { "flag" => "1" })).to be(false)
    expect(command.send(:features_changed?, { "flag" => 0 }, { "flag" => "0" })).to be(false)
    expect(command.send(:features_changed?, { "age" => 2 }, { "age" => 2.0 })).to be(false)
    expect(command.send(:features_changed?, { "tags" => [ 2, 1 ] }, { "tags" => [ 1, 2 ] })).to be(false)
  end

  it "skips save and event emission on unchanged replay" do
    clinical_record = import_and_validate_fci!

    with_tenant(membership) do
      CommandBus.dispatch(described_class, clinical_record_id: clinical_record.id)
    end

    snapshot = with_tenant(membership) { CitizenFeatureSnapshot.find_by!(clinical_record_id: clinical_record.id) }
    original_updated_at = snapshot.updated_at

    expect(Ai::FeatureExtractor).not_to receive(:call)

    expect do
      with_tenant(membership) do
        CommandBus.dispatch(described_class, clinical_record_id: clinical_record.id)
      end
    end.not_to change {
      with_tenant(membership) do
        DomainEvent.where(event_type: Cidadaobr::KafkaTopics::CLINICAL_FACT_EXTRACTED).count
      end
    }

    expect(with_tenant(membership) { snapshot.reload.updated_at }).to eq(original_updated_at)
  end

  it "re-extracts when citizen_id becomes available without clinical_record touch" do
    clinical_record = import_and_validate_fci!
    citizen = with_tenant(membership) { clinical_record.reload.citizen }

    with_tenant(membership) do
      CommandBus.dispatch(described_class, clinical_record_id: clinical_record.id)
      snapshot = CitizenFeatureSnapshot.find_by!(clinical_record_id: clinical_record.id)
      snapshot.update_columns(citizen_id: nil, updated_at: 1.hour.from_now)
    end

    expect(Ai::FeatureExtractor).to receive(:call).and_call_original

    with_tenant(membership) do
      CommandBus.dispatch(described_class, clinical_record_id: clinical_record.id)
    end

    snapshot = with_tenant(membership) { CitizenFeatureSnapshot.find_by!(clinical_record_id: clinical_record.id) }
    expect(snapshot.citizen_id).to eq(citizen.id)
  end

  it "re-extracts when payload changes without clinical_record touch" do
    clinical_record = import_and_validate_fci!

    with_tenant(membership) do
      CommandBus.dispatch(described_class, clinical_record_id: clinical_record.id)
      clinical_record.update_columns(
        payload_json: clinical_record.payload_json.merge("medicoes" => { "glicemia" => 99 })
      )
    end

    expect(Ai::FeatureExtractor).to receive(:call).and_call_original

    with_tenant(membership) do
      CommandBus.dispatch(described_class, clinical_record_id: clinical_record.id)
    end

    snapshot = with_tenant(membership) { CitizenFeatureSnapshot.find_by!(clinical_record_id: clinical_record.id) }
    expect(snapshot.features.dig("measurements", "glucose")).to eq(99)
    expect(snapshot.features).not_to have_key("_source")
    expect(snapshot.source_payload_digest).to be_present
  end

  it "re-extracts when FeatureExtractor logic version changes" do
    clinical_record = import_and_validate_fci!

    with_tenant(membership) do
      CommandBus.dispatch(described_class, clinical_record_id: clinical_record.id)
      snapshot = CitizenFeatureSnapshot.find_by!(clinical_record_id: clinical_record.id)
      snapshot.update_columns(source_payload_digest: "stale-digest")
    end

    expect(Ai::FeatureExtractor).to receive(:call).and_call_original

    with_tenant(membership) do
      CommandBus.dispatch(described_class, clinical_record_id: clinical_record.id)
    end
  end

  it "persists under facility tenant scope" do
    facility_membership = create(
      :user_municipality_membership,
      municipality: municipality,
      health_facility: facility,
      scope: "facility"
    )
    clinical_record = import_and_validate_fci!

    expect do
      with_tenant(facility_membership) do
        CommandBus.dispatch(described_class, clinical_record_id: clinical_record.id)
      end
    end.to change { with_tenant(facility_membership) { CitizenFeatureSnapshot.count } }.by(1)
  end

  it "persists snapshot for FCD without citizen_id" do
    clinical_record = with_tenant(membership) do
      transport = TransportRecord.create!(
        municipality: municipality,
        health_facility: facility,
        serialized_uuid: SecureRandom.uuid,
        serialized_type: "FCD",
        cnes: facility.cnes,
        ibge_code: municipality.ibge_code,
        payload_binary: "\x00",
        ledi_version: Rails.application.config.ledi.fetch(:version),
        status: "validated"
      )
      ClinicalRecord.create!(
        municipality: municipality,
        health_facility: facility,
        transport_record: transport,
        record_type: "FCD",
        record_uuid: SecureRandom.uuid,
        payload_schema_version: Rails.application.config.ledi.fetch(:version),
        validation_status: "valid",
        validation_errors: [],
        payload_json: { "uuid" => SecureRandom.uuid }
      )
    end

    expect do
      with_tenant(membership) do
        CommandBus.dispatch(described_class, clinical_record_id: clinical_record.id)
      end
    end.to change { with_tenant(membership) { CitizenFeatureSnapshot.count } }.by(1)

    snapshot = with_tenant(membership) { CitizenFeatureSnapshot.last }
    expect(snapshot.citizen_id).to be_nil
    expect(snapshot.record_type).to eq("FCD")
  end

  it "skips non-valid clinical records without persisting" do
    clinical_record = with_tenant(membership) do
      transport = TransportRecord.create!(
        municipality: municipality,
        health_facility: facility,
        serialized_uuid: SecureRandom.uuid,
        serialized_type: "FCI",
        cnes: facility.cnes,
        ibge_code: municipality.ibge_code,
        payload_binary: "\x00",
        ledi_version: Rails.application.config.ledi.fetch(:version),
        status: "validated"
      )
      ClinicalRecord.create!(
        municipality: municipality,
        health_facility: facility,
        transport_record: transport,
        record_type: "FCI",
        record_uuid: SecureRandom.uuid,
        payload_schema_version: Rails.application.config.ledi.fetch(:version),
        validation_status: "pending",
        validation_errors: [],
        payload_json: { "uuid" => SecureRandom.uuid }
      )
    end

    expect(Rails.logger).to receive(:warn).with(/feature_snapshot\.validation_skipped/)
    expect do
      with_tenant(membership) do
        CommandBus.dispatch(described_class, clinical_record_id: clinical_record.id)
      end
    end.not_to change { with_tenant(membership) { CitizenFeatureSnapshot.count } }
  end
end
