# frozen_string_literal: true

class KafkaProcessedEvent < ApplicationRecord
  validates :event_id, :topic, :consumer_group, :processed_at, presence: true
  validates :event_id, uniqueness: { scope: %i[topic consumer_group] }
end
