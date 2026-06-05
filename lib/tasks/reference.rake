# frozen_string_literal: true

namespace :reference do
  desc "Reference gate: import fixtures, sync catalog, publish release, validate manifest"
  task gate: :environment do
    release = Reference::Gate.run!
    puts "Reference gate OK — release #{release.release_key} (#{release.checksum.first(12)}...)"
  end
end
