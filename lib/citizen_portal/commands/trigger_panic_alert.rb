# frozen_string_literal: true

module CitizenPortal
  module Commands
    class TriggerPanicAlert < ApplicationCommand
      RECENT_ALERT_WINDOW = 5.minutes

      def initialize(latitude: nil, longitude: nil, citizen_account: nil)
        @latitude = latitude
        @longitude = longitude
        @citizen_account = citizen_account
      end

      def call
        tenant = Cidadaobr::TenantContext.current_or_raise!
        account = @citizen_account or raise ArgumentError, "citizen account is required"
        unless account.citizen_id == tenant.citizen_id
          raise ArgumentError, "citizen account does not match tenant scope"
        end

        citizen = account.citizen

        write_transaction do
          lock_citizen_for_panic!(citizen.id)
          assert_not_spamming!(citizen)

          alert = PanicAlert.create!(
            municipality_id: citizen.municipality_id,
            citizen_id: citizen.id,
            citizen_account_id: @citizen_account&.id,
            latitude: @latitude,
            longitude: @longitude,
            status: "triggered",
            triggered_at: Time.current
          )

          RecordPlatformEvent.call(
            event_type: Cidadaobr::KafkaTopics::PANIC_ALERT_TRIGGERED,
            aggregate_type: "PanicAlert",
            aggregate_id: alert.id,
            care_team_id: CareTeamRouting.resolve_care_team_id(citizen),
            payload: {
              panic_alert_id: alert.id,
              citizen_id: alert.citizen_id,
              triggered_at: alert.triggered_at.iso8601,
              latitude: alert.latitude,
              longitude: alert.longitude
            }
          )

          alert
        end
      end

      private

      # Per-citizen txn lock; hashtext collision across UUIDs is negligible at municipal scale.
      def lock_citizen_for_panic!(citizen_id)
        quoted = ActiveRecord::Base.connection.quote(citizen_id.to_s)
        ActiveRecord::Base.connection.execute("SELECT pg_advisory_xact_lock(hashtext(#{quoted}))")
      end

      def assert_not_spamming!(citizen)
        recent = PanicAlert.where(citizen_id: citizen.id, status: "triggered")
          .where(triggered_at: RECENT_ALERT_WINDOW.ago..)
          .exists?
        return unless recent

        raise ArgumentError, "panic alert already triggered recently"
      end
    end
  end
end
