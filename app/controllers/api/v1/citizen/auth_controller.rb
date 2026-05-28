# frozen_string_literal: true

module Api
  module V1
    module Citizen
      class AuthController < Api::ApplicationController
        include Api::V1::MembershipAuthentication
      end
    end
  end
end
