# frozen_string_literal: true

module ApiAuthHelpers
  def auth_headers_for(membership)
    token = JwtTokenService.encode(user: membership.user, membership: membership)
    { "Authorization" => "Bearer #{token}" }
  end
end

RSpec.configure do |config|
  config.include ApiAuthHelpers, type: :request
end
