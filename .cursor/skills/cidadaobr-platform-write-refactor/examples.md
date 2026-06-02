# Platform write — examples

## Gold: command + event + topic

From `lib/scheduling/commands/book_appointment.rb` (pattern only):

```ruby
# Inside ApplicationCommand#call:
write_transaction do
  # validations, AR writes, domain rules
  appointment = Appointment.create!(...)

  RecordPlatformEvent.call(
    event_type: "appointment.booked",
    aggregate_type: "Appointment",
    aggregate_id: appointment.id,
    payload: {
      appointment_id: appointment.id,
      citizen_id: appointment.citizen_id,
      scheduled_at: appointment.scheduled_at.iso8601
    },
    topic: OutboxPublisher::TOPIC_MAPPING.fetch("appointment.booked"),
    care_team_id: appointment.care_team_id
  )

  appointment
end
```

## Gold: controller dispatch

```ruby
def create
  @appointment = CommandBus.dispatch(
    Scheduling::BookAppointment,
    **appointment_params.to_h.symbolize_keys
  )
  redirect_to @appointment
end
```

## Anti-pattern: controller AR

```ruby
# BAD — move to lib/<context>/commands/
def create
  @citizen = Citizen.new(citizen_params)
  @citizen.save!
end
```

## Anti-pattern: command without tenant transaction

```ruby
# BAD
def self.call(attrs)
  Citizen.create!(attrs)
end
```

```ruby
# GOOD
def self.call(attrs)
  Cidadaobr::TenantRls.write_transaction do
    # apply_write_scope! if needed
    citizen = Citizen.create!(attrs.merge(tenant_scope(attrs)))
    # optional RecordPlatformEvent
    citizen
  end
end
```

## Anti-pattern: event type not in TOPIC_MAPPING

```ruby
# BAD — publish will fail or use wrong topic
topic: "some.random.topic"

# GOOD
topic: OutboxPublisher::TOPIC_MAPPING.fetch("campaign.targets.built")
```

Add key to `OutboxPublisher::TOPIC_MAPPING` in the same PR:

```ruby
"campaign.targets.built" => "campaign.targets.built",
```

## Spec snippet (event + outbox)

```ruby
expect {
  described_class.call(campaign: campaign, ...)
}.to change(DomainEvent, :count).by(1)
  .and change(OutboxMessage, :count).by(1)

event = DomainEvent.order(:created_at).last
expect(event.event_type).to eq("campaign.targets.built")
expect(OutboxMessage.last.topic).to eq(OutboxPublisher::TOPIC_MAPPING.fetch("campaign.targets.built"))
```

## New command skeleton (Onda B)

```ruby
# lib/campaigns/commands/build_campaign_target_list.rb
module Campaigns
  class BuildCampaignTargetList < ApplicationCommand
    def self.call(campaign:, performed_by:)
      Cidadaobr::TenantRls.write_transaction do
        # build targets, persist
        campaign.reload

        RecordPlatformEvent.call(
          event_type: "campaign.targets.built",
          aggregate_type: "HomeVisitCampaign",
          aggregate_id: campaign.id,
          payload: { campaign_id: campaign.id, target_count: campaign.targets.count },
          topic: OutboxPublisher::TOPIC_MAPPING.fetch("campaign.targets.built"),
          care_team_id: campaign.care_team_id
        )

        campaign
      end
    end
  end
end
```

Adjust `ApplicationCommand` API to match project base if it uses instance `#call` instead of `.call`.
