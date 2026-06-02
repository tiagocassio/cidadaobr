# frozen_string_literal: true

module Platform
  module Commands
    class RegisterMunicipalUser < ApplicationCommand
      Result = Data.define(:success, :user, :membership)

      def initialize(user:, membership:)
        @user = user
        @membership = membership
      end

      def call
        success = false
        write_transaction do
          success = @user.save && @membership.save
          raise ActiveRecord::Rollback unless success
        end
        Result.new(success: success, user: @user, membership: @membership)
      end
    end
  end
end
