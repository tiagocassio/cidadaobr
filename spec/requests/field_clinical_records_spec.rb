# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Field clinical record validation API", type: :request do
  let(:municipality) { create(:municipality, ibge_code: "3550308") }
  let(:facility) { create(:health_facility, municipality: municipality, cnes: "2000001") }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, health_facility: facility, scope: "facility")
  end

  before do
    load Rails.root.join("db/seeds/ledi_catalog.rb")
  end

  def import_clinical_record!
    with_tenant(membership) do
      Ledi::ImportTransportRecord.call(
        payload_binary: LediFixtures.fci_binary(cnes: facility.cnes, ibge: municipality.ibge_code)
      )[:clinical_record]
    end
  end

  it "validates a clinical record and returns validation_errors" do
    clinical_record = import_clinical_record!

    post "/api/v1/field/clinical_records/#{clinical_record.id}/validate",
         headers: auth_headers_for(membership)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body).to include(
      "clinical_record_id" => clinical_record.id,
      "valid" => true,
      "validation_errors" => []
    )
  end

  it "returns unauthorized without a bearer token" do
    clinical_record = import_clinical_record!

    post "/api/v1/field/clinical_records/#{clinical_record.id}/validate"

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns not found for clinical records outside the tenant scope" do
    other_facility = create(:health_facility, municipality: municipality, cnes: "2000002", name: "UBS B")
    other_membership = create(
      :user_municipality_membership,
      municipality: municipality,
      health_facility: other_facility,
      scope: "facility"
    )
    clinical_record = with_tenant(other_membership) do
      Ledi::ImportTransportRecord.call(
        payload_binary: LediFixtures.fci_binary(cnes: other_facility.cnes, ibge: municipality.ibge_code)
      )[:clinical_record]
    end

    post "/api/v1/field/clinical_records/#{clinical_record.id}/validate",
         headers: auth_headers_for(membership)

    expect(response).to have_http_status(:not_found)
  end
end
