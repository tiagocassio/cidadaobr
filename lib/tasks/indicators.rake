# frozen_string_literal: true

namespace :indicators do
  namespace :catalog do
    desc "Seed Portaria 3.493 indicator catalog (CVAT, V-*, C1–C15)"
    task seed: :environment do
      load Rails.root.join("db/seeds/indicator_catalog.rb")
    end
  end
end
