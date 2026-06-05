# frozen_string_literal: true

class SharedCareEvolution < ApplicationRecord
  belongs_to :shared_care_case
  belongs_to :author_user, class_name: "User", optional: true

  validates :evolution_note, presence: true
end
