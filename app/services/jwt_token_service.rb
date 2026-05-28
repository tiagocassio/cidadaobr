# frozen_string_literal: true

class JwtTokenService
  SECRET = Rails.application.secret_key_base
  ALGORITHM = "HS256"

  class << self
    def encode(user:, membership:)
      payload = {
        sub: user.id,
        email: user.email,
        municipality_id: membership.municipality_id,
        scope: membership.scope,
        health_facility_id: membership.health_facility_id,
        team_ids: user.team_ids_for(membership.municipality_id),
        exp: 12.hours.from_now.to_i
      }

      JWT.encode(payload, SECRET, ALGORITHM)
    end

    def decode(token)
      JWT.decode(token, SECRET, true, algorithm: ALGORITHM).first.symbolize_keys
    rescue JWT::DecodeError
      nil
    end
  end
end
