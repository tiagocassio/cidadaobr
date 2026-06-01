# frozen_string_literal: true

module Inventory
  module Commands
    class UpdateCampaignProvisioning
      class << self
        def call(campaign:, totals:, route_date: nil)
          record = campaign.home_visit_campaign_provisioning
          raise ArgumentError, "provisionamento não calculado" if record.blank?
          if record.status.in?(%w[reserved dispatched])
            raise ArgumentError, "provisionamento bloqueado para edição após reserva"
          end

          normalized = totals.map do |line|
            line.stringify_keys.slice(
              "key", "label", "quantity_required", "unit",
              "supply_item_code", "immunobiological_product_id"
            ).tap do |entry|
              entry["quantity_required"] = entry["quantity_required"].to_i
            end
          end

          record.update!(totals_json: normalized)
          Inventory::PreviewCampaignProvisioning.apply_campaign_totals_to_routes!(
            campaign: campaign.reload,
            totals: normalized,
            route_date: route_date
          )
          Inventory::PreviewCampaignProvisioning.rollup_status!(campaign: campaign.reload, route_date: route_date)
          record.reload
        end
      end
    end
  end
end
