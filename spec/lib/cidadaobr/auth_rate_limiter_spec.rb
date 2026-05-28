# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cidadaobr::AuthRateLimiter do
  include ActiveSupport::Testing::TimeHelpers
  around do |example|
    described_class.reset!
    example.run
    described_class.reset!
  end

  it "blocks after the configured number of failed attempts" do
    key = "127.0.0.1:test-municipality"

    described_class::MAX_ATTEMPTS.times do
      described_class.record_failure!(scope: "citizen_auth", key: key)
    end

    expect(described_class.blocked?(scope: "citizen_auth", key: key)).to be(true)
  end

  it "does not block before failures are recorded" do
    key = "127.0.0.1:clean"

    expect(described_class.blocked?(scope: "citizen_auth", key: key)).to be(false)
  end

  it "drops expired entries instead of keeping them forever" do
    key = "127.0.0.1:expired"

    described_class::MAX_ATTEMPTS.times do
      described_class.record_failure!(scope: "citizen_auth", key: key)
    end

    travel described_class::WINDOW + 1.second do
      expect(described_class.blocked?(scope: "citizen_auth", key: key)).to be(false)
    end
  end

  it "clears failures after a successful reset" do
    key = "127.0.0.1:success"

    described_class::MAX_ATTEMPTS.times do
      described_class.record_failure!(scope: "citizen_auth", key: key)
    end

    described_class.clear_key!(scope: "citizen_auth", key: key)

    expect(described_class.blocked?(scope: "citizen_auth", key: key)).to be(false)
  end
end
