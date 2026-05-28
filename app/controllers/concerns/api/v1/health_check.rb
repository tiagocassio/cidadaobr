# frozen_string_literal: true

module Api
  module V1
    module HealthCheck
      extend ActiveSupport::Concern

      included do
        class_attribute :health_channel_name, instance_writer: false
      end

      def show
        @channel = self.class.health_channel_name
        render "api/v1/health/show"
      end

      class_methods do
        # Configure once per controller class.
        def health_channel(channel)
          self.health_channel_name = channel
        end
      end
    end
  end
end
