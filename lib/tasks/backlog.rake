# frozen_string_literal: true

namespace :backlog do
  desc "Copy APS municipal backlog CSV from docs/backlog to path (default: same source)"
  task export: :environment do
    source = Rails.root.join("docs/backlog/aps-municipal-backlog.csv")
    path = Pathname(ENV.fetch("path", source))

    unless source.exist?
      abort "Missing backlog source: #{source}"
    end

    if path.expand_path == source.expand_path
      puts "Backlog at #{source} (#{source.readlines.size - 1} items)"
    else
      FileUtils.mkdir_p(path.dirname)
      FileUtils.cp(source, path)
      puts "Copied backlog to #{path}"
    end
  end
end
