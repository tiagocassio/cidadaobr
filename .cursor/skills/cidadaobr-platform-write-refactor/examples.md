# Platform write — examples

## Gold: command + event

From `lib/scheduling/commands/book_appointment.rb` (pattern only):

```ruby
write_transaction do
  appointment = Appointment.create!(...)

  RecordPlatformEvent.call(
    event_type: Cidadaobr::KafkaTopics::APPOINTMENT_BOOKED,
    aggregate_type: "Appointment",
    aggregate_id: appointment.id,
    payload: {
      appointment_id: appointment.id,
      citizen_id: appointment.citizen_id,
      scheduled_at: appointment.scheduled_at.iso8601
    },
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

## Anti-pattern: separate topic name

```ruby
# BAD — event_type and Kafka topic must match
RecordPlatformEvent.call(
  event_type: "appointment.booked",
  topic: "appointment-booked",
  ...
)

# GOOD
RecordPlatformEvent.call(
  event_type: Cidadaobr::KafkaTopics::APPOINTMENT_BOOKED,
  ...
)
```

## Command skeleton (campaigns)

Ver implementação em `lib/campaigns/commands/build_campaign_target_list.rb` (`RecordPlatformEvent` + `Cidadaobr::KafkaTopics`).

## Spec snippet (event + outbox)

```ruby
expect {
  described_class.call(campaign: campaign)
}.to change(DomainEvent, :count).by(1)
  .and change(OutboxMessage, :count).by(1)

expect(DomainEvent.last.event_type).to eq(Cidadaobr::KafkaTopics::CAMPAIGN_TARGETS_BUILT)
expect(OutboxMessage.last.topic).to eq(Cidadaobr::KafkaTopics::CAMPAIGN_TARGETS_BUILT)
```
