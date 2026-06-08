# frozen_string_literal: true

class AddSourcePayloadDigestToCitizenFeatureSnapshots < ActiveRecord::Migration[8.1]
  def change
    return if column_exists?(:citizen_feature_snapshots, :source_payload_digest)

    add_column :citizen_feature_snapshots, :source_payload_digest, :string
  end
end
