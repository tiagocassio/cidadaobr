# frozen_string_literal: true

module Platform
  module Commands
    class UpdateMunicipalUser < ApplicationCommand
      Result = Data.define(:success, :user, :membership)

      def initialize(user:, membership:, user_attributes:, membership_attributes:)
        @user = user
        @membership = membership
        @user_attributes = user_attributes
        @membership_attributes = membership_attributes
      end

      def call
        success = false
        write_transaction do
          success = @user.update(@user_attributes) && @membership.update(@membership_attributes)
          raise ActiveRecord::Rollback unless success
        end
        Result.new(success: success, user: @user, membership: @membership)
      end
    end
  end
end
