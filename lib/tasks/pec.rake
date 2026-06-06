# frozen_string_literal: true

namespace :pec do
  desc "Re-save municipality PEC API tokens so plain-text values are encrypted at rest"
  task encrypt_tokens: :environment do
    count = 0
    Municipality.where.not(pec_api_token: [ nil, "" ]).find_each do |municipality|
      municipality.update!(pec_api_token: municipality.pec_api_token)
      count += 1
    end

    puts "Encrypted #{count} municipality PEC token(s)"
  end
end
