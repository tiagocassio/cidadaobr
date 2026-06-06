# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "pec:encrypt_tokens" do
  before do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  it "re-saves municipality tokens without error" do
    municipality = create(:municipality, pec_api_token: "rotate-me")

    expect do
      Rake::Task["pec:encrypt_tokens"].invoke
    end.not_to raise_error

    expect(municipality.reload.pec_api_token).to eq("rotate-me")
  ensure
    Rake::Task["pec:encrypt_tokens"].reenable
  end
end
