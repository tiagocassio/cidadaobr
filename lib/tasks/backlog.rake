# frozen_string_literal: true

require "csv"

namespace :backlog do
  desc "Export APS municipal backlog CSV from plan metadata"
  task export: :environment do
    path = ENV.fetch("path", Rails.root.join("docs/backlog/aps-municipal-backlog.csv"))
    FileUtils.mkdir_p(File.dirname(path))

    rows = [
      %w[work_item_type id parent_id epic_id title phase labels depends_on legacy_ref],
      %w[Epic EPIC-00 EPIC-00 CidadãoBR\ Saúde\ —\ Core\ Plataforma 0 backend;infra F0],
      %w[Story STORY-00-01 EPIC-00 EPIC-00 [Core]\ CidadãoBR\ Saúde\ —\ Bootstrap\ e\ convenções 0 backend F0-01],
      %w[Task TASK-00-01 STORY-00-01 EPIC-00 [Core]\ CidadãoBR\ Saúde\ —\ Bootstrap\ Rails\ application 0 backend F0-01]
    ]

    CSV.open(path, "w") do |csv|
      rows.each { |row| csv << row }
    end

    puts "Exported backlog to #{path}"
  end
end
