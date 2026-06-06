# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reference::LediCatalogVendorParser do
  it "imports field paths from vendored LEDI thrift types" do
    count = described_class.call

    expect(count).to be > 0
    expect(
      LediFieldCatalog.find_by!(
        record_type: "FAO",
        field_path: "uuid_ficha",
        ledi_version: Rails.application.config.ledi.fetch(:version)
      )
    ).to be_present
  end

  it "parses every vendored thrift root struct (gate on LEDI bump)" do
    vendor_dir = Rails.root.join("vendor/ledi/#{Rails.application.config.ledi.fetch(:version)}/gen-rb")

    described_class::THRIFT_FILES.each_key do |filename|
      path = vendor_dir.join(filename)
      next unless path.exist?

      structs = described_class.send(:parse_struct_definitions, path.read)
      root = described_class::ROOT_STRUCT_BY_FILE.fetch(filename)

      expect(structs).to have_key(root), "expected #{root} in #{filename}"
      expect(structs.fetch(root)).not_to be_empty
    end
  end

  it "marks required Thrift fields from :optional metadata" do
    described_class.call

    required_field = LediFieldCatalog.find_by!(
      record_type: "FAO",
      field_path: "uuid_ficha",
      ledi_version: Rails.application.config.ledi.fetch(:version)
    )
    optional_field = LediFieldCatalog.find_by!(
      record_type: "FCI",
      field_path: "identificacao_usuario_cidadao.nome_social",
      ledi_version: Rails.application.config.ledi.fetch(:version)
    )

    expect(required_field.required).to be(true)
    expect(required_field.min_occurs).to eq(1)
    expect(optional_field.required).to be(false)
    expect(optional_field.min_occurs).to eq(0)
  end

  it "imports nested FCI paths from struct references" do
    described_class.call

    expect(
      LediFieldCatalog.find_by!(
        record_type: "FCI",
        field_path: "identificacao_usuario_cidadao.cpf_cidadao",
        ledi_version: Rails.application.config.ledi.fetch(:version)
      )
    ).to be_present
  end
end
