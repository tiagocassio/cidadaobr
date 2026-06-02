# frozen_string_literal: true

require "rails_helper"

RSpec.describe Territory::Commands::RegisterCitizen do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  it "records citizen.registered platform event" do
    with_tenant(membership) do
      expect {
        described_class.call(
          citizen_attributes: {
            full_name: "Maria Event",
            cpf: "39053344705",
            health_facility_id: facility.id,
            care_team_id: team.id
          }
        )
      }.to change(DomainEvent, :count).by(1)
        .and change(OutboxMessage, :count).by(1)

      expect(DomainEvent.order(:created_at).last.event_type).to eq(Cidadaobr::KafkaTopics::CITIZEN_REGISTERED)
    end
  end
end
