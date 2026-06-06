# frozen_string_literal: true

require "rails_helper"

RSpec.describe Municipality do
  it "encrypts pec_api_token at rest" do
    municipality = create(:municipality, pec_api_token: "secret-token")

    raw_value = ActiveRecord::Base.connection.select_value(
      "SELECT pec_api_token FROM municipalities WHERE id = #{ActiveRecord::Base.connection.quote(municipality.id)}"
    )

    expect(raw_value).not_to eq("secret-token")
    expect(municipality.reload.pec_api_token).to eq("secret-token")
  end
end
