# frozen_string_literal: true

module IndicatorsHelper
  def indicator_catalog_name(code)
    key = "cidadaobr.indicators.catalog.#{code}.name"
    return I18n.t(key) if I18n.exists?(key)

    code
  end

  # Letter keys (B–K) are generic MVP labels until multi-BP seed adds per-indicator SAPS text.
  def good_practice_label(code)
    return t("cidadaobr.common.empty") if code.blank?

    key = "cidadaobr.indicators.good_practices.#{code}"
    return I18n.t(key) if I18n.exists?(key)

    code
  end

  def indicator_tier_label(tier)
    return t("cidadaobr.common.empty") if tier.blank?

    key = "cidadaobr.indicators.tiers.#{tier}"
    return I18n.t(key) if I18n.exists?(key)

    tier
  end
end
