# frozen_string_literal: true

require "net/http"
require "tmpdir"
require "zip"

module Reference
  class SigtapRemoteFetcher
    class FetchError < StandardError; end

    ZIP_URL_TEMPLATE = "https://ftp.datasus.gov.br/datasus-arquivos/susp/procedimentos/TabelaUnificada_%<competence>s.zip"
    PROCEDURE_CODE_WIDTH = 10
    PROCEDURE_NAME_WIDTH = 250

    Entry = Data.define(:code, :label, :competence)

    class << self
      def fetch_entries(competence:)
        return if use_fixture?

        download_and_parse(competence)
      rescue StandardError => e
        if ActiveModel::Type::Boolean.new.cast(ENV["SIGTAP_LIVE"])
          Rails.logger.error("[SIGTAP] remote fetch failed for #{competence}: #{e.message}")
        else
          Rails.logger.warn("[SIGTAP] remote fetch failed for #{competence}: #{e.message}")
        end
        nil
      end

      def use_fixture?
        return true if Rails.env.test?
        return true if ActiveModel::Type::Boolean.new.cast(ENV["SIGTAP_USE_FIXTURE"])

        !ActiveModel::Type::Boolean.new.cast(ENV["SIGTAP_LIVE"])
      end

      private

      def download_and_parse(competence)
        uri = URI.parse(format(ZIP_URL_TEMPLATE, competence: competence))
        entries = []

        Dir.mktmpdir("sigtap") do |dir|
          zip_path = File.join(dir, "sigtap.zip")
          download!(uri, zip_path)
          procedure_path = extract_procedure_table!(zip_path, dir)

          File.foreach(procedure_path) do |line|
            parsed = parse_line(line, competence)
            entries << parsed if parsed
          end
        end

        entries.presence || raise(FetchError, "no procedures parsed from SIGTAP archive")
      end

      def extract_procedure_table!(zip_path, destination)
        procedure_path = nil

        Zip::File.open(zip_path) do |zip|
          entry = zip.glob("**/tb_procedimento.txt").first || zip.glob("**/TB_PROCEDIMENTO.txt").first
          raise FetchError, "tb_procedimento.txt not found in SIGTAP archive" unless entry

          procedure_path = File.join(destination, "tb_procedimento.txt")
          entry.extract(procedure_path) { true }
        end

        procedure_path
      end

      def download!(uri, destination)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 120) do |http|
          request = Net::HTTP::Get.new(uri)
          http.request(request) do |response|
            raise FetchError, "SIGTAP HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

            File.open(destination, "wb") do |file|
              response.read_body { |chunk| file.write(chunk) }
            end
          end
        end
      end

      def parse_line(line, competence)
        text = line.to_s.delete("\r")
        return if text.blank?
        return if text.length < PROCEDURE_CODE_WIDTH

        code = text[0, PROCEDURE_CODE_WIDTH].strip
        label = text[PROCEDURE_CODE_WIDTH, PROCEDURE_NAME_WIDTH]&.strip
        return if code.blank? || label.blank?

        Entry.new(code: code, label: label, competence: competence)
      end
    end
  end
end
