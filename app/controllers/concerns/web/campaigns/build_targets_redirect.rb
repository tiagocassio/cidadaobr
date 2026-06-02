# frozen_string_literal: true

module Web
  module Campaigns
    module BuildTargetsRedirect
      extend ActiveSupport::Concern

      private

      def redirect_after_build_targets!(result, redirect_path)
        if result.created_count.positive?
          redirect_to redirect_path, notice: t("cidadaobr.campaigns.flash.targets_built", count: result.created_count)
        elsif result.updated_count.positive?
          redirect_to redirect_path, notice: t("cidadaobr.campaigns.flash.targets_synced", count: result.updated_count)
        elsif result.eligible_count.positive?
          redirect_to redirect_path, notice: t("cidadaobr.campaigns.flash.targets_already_current", eligible: result.eligible_count)
        else
          redirect_to redirect_path,
                      alert: t("cidadaobr.campaigns.flash.targets_built_empty", eligible: result.eligible_count)
        end
      end
    end
  end
end
