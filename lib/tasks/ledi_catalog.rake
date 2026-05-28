# frozen_string_literal: true

namespace :ledi do
  namespace :catalog do
    desc "Import LEDI field catalog from vendor XSD (stub — extend for full XSD parsing)"
    task import_xsd: :environment do
      xsd_root = Rails.root.join("vendor/ledi/#{Rails.application.config.ledi.fetch(:version)}")
      puts "LEDI catalog XSD import is not fully automated yet."
      puts "Vendor XSD reference path: #{xsd_root}"
      puts "Run db:seed to load MVP validation rules and field catalog entries."
    end

    desc "Reload MVP LEDI catalog seeds"
    task seed: :environment do
      load Rails.root.join("db/seeds/ledi_catalog.rb")
    end
  end
end
