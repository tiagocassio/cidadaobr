# frozen_string_literal: true

require "rails_helper"

RSpec.describe Territory::Commands::CreateCareTeam do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  it "records care_team.created platform event" do
    with_tenant(membership) do
      team = CareTeam.new

      expect {
        described_class.call(
          care_team: team,
          attributes: {
            name: "Equipe ESF 99",
            ine: "0000000099",
            health_facility_id: facility.id,
            team_kind: "esf"
          },
          municipality: municipality
        )
      }.to change(DomainEvent, :count).by(1)

      expect(DomainEvent.order(:created_at).last.event_type).to eq(Cidadaobr::KafkaTopics::CARE_TEAM_CREATED)
    end
  end
end
