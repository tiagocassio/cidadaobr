# frozen_string_literal: true

namespace :ledi do
  namespace :fixtures do
    desc "Write LEDI transport binaries to spec/fixtures/ledi"
    task dump: :environment do
      require Rails.root.join("spec/support/ledi_fixtures")

      directory = Rails.root.join("spec/fixtures/ledi")
      FileUtils.mkdir_p(directory)

      {
        "fci.bin" => LediFixtures.fci_binary,
        "fcd.bin" => LediFixtures.fcd_binary,
        "fai.bin" => LediFixtures.fai_binary
      }.each do |filename, binary|
        path = directory.join(filename)
        File.binwrite(path, binary)
        puts "Wrote #{path} (#{binary.bytesize} bytes)"
      end
    end
  end
end
