# frozen_string_literal: true

class AddConsultationRoomToVaccinationCampaigns < ActiveRecord::Migration[8.1]
  def change
    add_reference :vaccination_campaigns, :consultation_room, foreign_key: true, type: :uuid, null: true
  end
end
