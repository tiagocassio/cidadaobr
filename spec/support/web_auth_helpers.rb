# frozen_string_literal: true

module WebAuthHelpers
  def sign_in_web(user:, membership:)
    post web_login_path, params: {
      email: user.email,
      password: "password123",
      municipality_id: membership.municipality_id
    }
  end
end

RSpec.configure do |config|
  config.include WebAuthHelpers, type: :request
end
