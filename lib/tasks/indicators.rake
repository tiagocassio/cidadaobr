# frozen_string_literal: true

namespace :indicators do
  namespace :catalog do
    desc "Seed Portaria 3.493 indicator catalog (CVAT, V-*, C1–C15)"
    task seed: :environment do
      load Rails.root.join("db/seeds/indicator_catalog.rb")
    end
  end

  namespace :gaps do
    desc "Detect citizen indicator gaps (prefer CITIZEN_ID or CARE_TEAM_ID; optional INDICATOR_CODES)"
    task detect: :environment do
      tenant = Cidadaobr::TenantContext.current_or_raise!
      if Rails.env.production? && ENV["CITIZEN_ID"].blank? && ENV["CARE_TEAM_ID"].blank?
        abort "Set CITIZEN_ID or CARE_TEAM_ID in production to avoid scanning the whole municipality"
      end

      puts "Detecting gaps for municipality #{tenant.municipality_id}..."

      result = Indicators::DetectCitizenGaps.call(
        citizen_id: ENV["CITIZEN_ID"],
        care_team_id: ENV["CARE_TEAM_ID"],
        indicator_codes: ENV["INDICATOR_CODES"]&.split(",")
      )
      puts result.inspect
    end
  end

  namespace :teams do
    desc "Recalculate team indicator scores (requires CARE_TEAM_ID, optional QUADRIMESTER, INDICATOR_CODES)"
    task recalculate: :environment do
      care_team_id = ENV.fetch("CARE_TEAM_ID")
      tenant = Cidadaobr::TenantContext.current_or_raise!
      puts "Recalculating scores for team #{care_team_id} in municipality #{tenant.municipality_id}..."

      results = Indicators::RecalculateTeamScore.call(
        care_team_id: care_team_id,
        quadrimester: ENV["QUADRIMESTER"],
        indicator_codes: ENV["INDICATOR_CODES"]&.split(",")
      )
      puts "Updated #{results.size} team indicator result(s)"
    end
  end
end
