# frozen_string_literal: true

require "rails_helper"

RSpec.describe CitizenPortal::Commands::TriggerPanicAlert do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let!(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:tenant_scope) do
    Cidadaobr::TenantScope.new(
      municipality_id: municipality.id,
      scope: "municipality",
      health_facility_id: nil,
      team_ids: [],
      citizen_id: nil
    )
  end
  let(:citizen) do
    with_tenant(tenant_scope) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
    end
  end
  let!(:account) do
    with_tenant(tenant_scope) do
      CitizenAccount.create!(municipality: municipality, citizen: citizen, cpf: citizen.cpf, password: "password123")
    end
  end
  let(:citizen_scope) { Cidadaobr::TenantScope.from_citizen_account(account) }

  it "allows only one concurrent trigger per citizen" do
    barrier = Concurrent::CyclicBarrier.new(2)
    results = Queue.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Cidadaobr::TenantContext.with(citizen_scope) do
            barrier.wait
            described_class.call(citizen_account: account, latitude: -23.5, longitude: -46.6)
            results << :ok
          end
        end
      rescue ArgumentError, ActiveRecord::RecordNotFound
        results << :rejected
      end
    end
    threads.each(&:join)

    collected = []
    collected << results.pop until results.empty?

    expect(collected.size).to eq(2)
    expect(collected.count { |result| result == :ok }).to eq(1)
    expect(collected.count { |result| result == :rejected }).to eq(1)

    Cidadaobr::TenantContext.with(citizen_scope) do
      expect(PanicAlert.where(citizen_id: citizen.id, status: "triggered").count).to eq(1)
    end
  end
end
