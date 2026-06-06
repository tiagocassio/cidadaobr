# frozen_string_literal: true

require "net/http"
require "json"

module Ledi
  class PecClient
    class Error < StandardError; end

    Response = Data.define(:accepted, :rejection_reason)
    MAX_ATTEMPTS = 3

    def initialize(base_url:, api_token: nil, open_timeout: 5, read_timeout: 30)
      @base_url = base_url.to_s.sub(%r{/\z}, "")
      @api_token = api_token
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    def submit_batch(batch:)
      records = batch.transport_records.where(status: "validated")
      raise Error, "batch has no validated transport records" if records.none?

      uri = submission_uri(batch.batch_number)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/octet-stream"
      request["Authorization"] = "Bearer #{@api_token}" if @api_token.present?
      request.body = BatchPayloadPack.pack(records)

      response = perform_with_retry(uri, request)
      parse_response(response)
    end

    private

    def submission_uri(batch_number)
      URI.join("#{@base_url}/", "api/v1/ledi/lotes/#{batch_number}")
    end

    def perform_with_retry(uri, request)
      attempts = 0
      last_response = nil

      while attempts < MAX_ATTEMPTS
        attempts += 1
        begin
          last_response = perform_once(uri, request)
          break unless retryable_response?(last_response)
        rescue Error
          raise if attempts >= MAX_ATTEMPTS
        end

        sleep(0.5 * attempts) if attempts < MAX_ATTEMPTS
      end

      last_response
    end

    def perform_once(uri, request)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: @open_timeout, read_timeout: @read_timeout) do |http|
        http.request(request)
      end
    rescue SocketError, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
      raise Error, e.message
    end

    def retryable_response?(response)
      code = response.code.to_i
      code >= 500 || code == 429
    end

    def parse_response(response)
      unless response.is_a?(Net::HTTPSuccess)
        return Response.new(false, "PEC HTTP #{response.code}: #{response.body.to_s.truncate(500)}")
      end

      body_str = response.body.to_s
      unless body_str.lstrip.match?(/\A[\[{]/)
        return Response.new(false, "PEC response is not valid JSON")
      end

      body = JSON.parse(body_str)
      if body["status"] == "accepted"
        Response.new(true, nil)
      else
        Response.new(false, body["reason"].presence || body["status"].to_s)
      end
    rescue JSON::ParserError
      Response.new(false, "PEC response is not valid JSON")
    end
  end
end
