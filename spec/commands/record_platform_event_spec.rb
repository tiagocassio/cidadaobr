# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecordPlatformEvent do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:care_team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:user) { create(:user) }

  before do
    create(:user_team_assignment, user: user, care_team: care_team)
  end

  it "persists care_team_id on domain events for team-scoped tenants" do
    membership = create(
      :user_municipality_membership,
      user: user,
      municipality: municipality,
      scope: "team"
    )

    event = with_tenant(membership) do
      described_class.call(
        event_type: Cidadaobr::KafkaTopics::DOMAIN_OUTBOX,
        aggregate_type: "Platform",
        aggregate_id: SecureRandom.uuid,
        payload: { ok: true },
        topic: Cidadaobr::KafkaTopics::DOMAIN_OUTBOX
      )
    end

    expect(event.care_team_id).to eq(care_team.id)

    envelope = with_tenant(membership) do
      OutboxMessage.find_by!(domain_event_id: event.id).payload
    end
    expect(envelope["care_team_id"]).to eq(care_team.id)
  end

  it "allows explicit care_team_id override from import commands" do
    membership = create(
      :user_municipality_membership,
      municipality: municipality,
      health_facility: facility,
      scope: "facility"
    )

    event = with_tenant(membership) do
      described_class.call(
        event_type: Cidadaobr::KafkaTopics::CLINICAL_RECORD_IMPORTED,
        aggregate_type: "ClinicalRecord",
        aggregate_id: SecureRandom.uuid,
        payload: { ok: true },
        topic: Cidadaobr::KafkaTopics::CLINICAL_RECORD_IMPORTED,
        care_team_id: care_team.id
      )
    end

    expect(event.care_team_id).to eq(care_team.id)
  end

  it "retries when aggregate version collides" do
    membership = create(
      :user_municipality_membership,
      municipality: municipality,
      health_facility: facility,
      scope: "facility"
    )
    aggregate_id = SecureRandom.uuid
    call_count = 0
    relation = instance_double(ActiveRecord::Relation)

    allow(DomainEvent).to receive(:where).with(aggregate_type: "Platform", aggregate_id: aggregate_id).and_return(relation)
    allow(relation).to receive(:maximum).with(:version) do
      call_count += 1
      call_count == 1 ? 0 : 1
    end
    allow(DomainEvent).to receive(:append!) do |**attrs|
      if call_count == 1
        raise ActiveRecord::RecordNotUnique.new(
          "duplicate key value violates unique constraint \"index_domain_events_on_aggregate_version\""
        )
      end

      DomainEvent.create!(
        aggregate_type: attrs[:aggregate_type],
        aggregate_id: attrs[:aggregate_id],
        event_type: attrs[:event_type],
        payload: attrs[:payload],
        metadata: attrs[:metadata] || {},
        occurred_at: attrs[:occurred_at],
        version: attrs[:version],
        municipality_id: attrs[:municipality_id],
        health_facility_id: attrs[:health_facility_id],
        care_team_id: attrs[:care_team_id]
      )
    end

    event = with_tenant(membership) do
      described_class.call(
        event_type: Cidadaobr::KafkaTopics::DOMAIN_OUTBOX,
        aggregate_type: "Platform",
        aggregate_id: aggregate_id,
        payload: { ok: true },
        topic: Cidadaobr::KafkaTopics::DOMAIN_OUTBOX
      )
    end

    expect(event.version).to eq(2)
    expect(call_count).to eq(2)
  end

  it "raises when team scope spans multiple care teams without explicit care_team_id" do
    other_team = create(:care_team, municipality: municipality, health_facility: facility, ine: "0000000002")
    create(:user_team_assignment, user: user, care_team: other_team)
    membership = create(
      :user_municipality_membership,
      user: user,
      municipality: municipality,
      scope: "team"
    )

    expect do
      with_tenant(membership) do
        described_class.call(
          event_type: Cidadaobr::KafkaTopics::DOMAIN_OUTBOX,
          aggregate_type: "Platform",
          aggregate_id: SecureRandom.uuid,
          payload: { ok: true },
          topic: Cidadaobr::KafkaTopics::DOMAIN_OUTBOX
        )
      end
    end.to raise_error(Ledi::Errors::AmbiguousTeamScopeError, /exactly one care team/)
  end

  it "raises when team scope has no assigned care teams" do
    membership = create(
      :user_municipality_membership,
      user: create(:user),
      municipality: municipality,
      scope: "team"
    )

    expect do
      with_tenant(membership) do
        described_class.call(
          event_type: Cidadaobr::KafkaTopics::DOMAIN_OUTBOX,
          aggregate_type: "Platform",
          aggregate_id: SecureRandom.uuid,
          payload: { ok: true },
          topic: Cidadaobr::KafkaTopics::DOMAIN_OUTBOX
        )
      end
    end.to raise_error(Ledi::Errors::AmbiguousTeamScopeError, /at least one assigned care team/)
  end
end
