# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledi::ValidationEngine do
  let(:municipality) { create(:municipality, ibge_code: "3550308") }
  let(:facility) { create(:health_facility, municipality: municipality, cnes: "2000001") }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, health_facility: facility, scope: "facility")
  end

  before do
    load Rails.root.join("db/seeds/ledi_catalog.rb")
  end

  def build_record(overrides = {})
    with_tenant(membership) do
      Ledi::ImportTransportRecord.call(
        payload_binary: LediFixtures.fci_binary(cnes: facility.cnes, ibge: municipality.ibge_code)
      )[:clinical_record].tap do |record|
        record.update!(payload_json: record.payload_json.merge(overrides.stringify_keys))
      end
    end
  end

  it "includes field_path for xor_present rule failures" do
    clinical_record = build_record(
      identificacao_usuario_cidadao: {
        cpf_cidadao: "39053344705",
        cns_cidadao: "898001160670703"
      }
    )

    result = with_tenant(membership) { described_class.call(clinical_record: clinical_record) }

    expect(result.valid).to be(false)
    expect(result.errors.find { |error| error[:code] == "citizen_identifier_xor" }[:field_path]).to include("cpf_cidadao")
  end

  it "fails closed for unknown rule types" do
    rule = LediValidationRule.find_by!(record_type: "FCI", rule_code: "tp_cds_origem_third_party")
    original_expression = rule.expression.deep_dup
    rule.update!(expression: original_expression.merge("type" => "unknown_rule_type"))

    clinical_record = build_record

    expect(Rails.error).to receive(:report).with(
      an_instance_of(StandardError),
      handled: true,
      severity: :warning,
      context: { rule_code: "tp_cds_origem_third_party", rule_type: "unknown_rule_type" }
    )

    result = with_tenant(membership) { described_class.call(clinical_record: clinical_record) }

    expect(result.valid).to be(false)
  ensure
    rule.update!(expression: original_expression) if rule && original_expression
  end
end
