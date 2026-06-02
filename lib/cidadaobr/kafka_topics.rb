# frozen_string_literal: true

module Cidadaobr
  # Canonical names used as both domain event_type and Kafka topic (hyphen-separated ASCII only).
  module KafkaTopics
    DOMAIN_OUTBOX = "domain-outbox"

    CLINICAL_RECORD_IMPORTED = "clinical-record-imported"
    CLINICAL_RECORD_VALIDATED = "clinical-record-validated"
    CLINICAL_RECORD_VALIDATION_FAILED = "clinical-record-validation-failed"
    CLINICAL_RECORD_PERSISTED = "clinical-record-persisted"

    LEDI_BATCH_SUBMITTED = "ledi-batch-submitted"
    LEDI_BATCH_STATUSCHANGED = "ledi-batch-statuschanged"

    APPOINTMENT_BOOKED = "appointment-booked"
    APPOINTMENT_WALK_IN_BOOKED = "appointment-walk-in-booked"
    APPOINTMENT_RESCHEDULED = "appointment-rescheduled"
    APPOINTMENT_CHECKEDIN = "appointment-checkedin"
    APPOINTMENT_COMPLETED = "appointment-completed"
    APPOINTMENT_CANCELLED = "appointment-cancelled"
    APPOINTMENT_NOSHOW = "appointment-noshow"

    INDICATOR_GAP_DETECTED = "indicator-gap-detected"
    INDICATOR_TEAM_SCORE_UPDATED = "indicator-team-score-updated"

    CITIZEN_REGISTERED = "citizen-registered"
    CITIZEN_UPDATED = "citizen-updated"

    CARE_TEAM_CREATED = "care-team-created"
    CARE_TEAM_UPDATED = "care-team-updated"

    VACCINATION_CAMPAIGN_PUBLISHED = "vaccination-campaign-published"
    VACCINATION_CAMPAIGN_DRAFT_INVALIDATED = "vaccination-campaign-draft-invalidated"
    VACCINATION_PROVISIONING_APPROVED = "vaccination-provisioning-approved"

    IMMUNOBIOLOGICAL_LOT_RECEIVED = "immunobiological-lot-received"

    SUPPLY_PROVISIONING_REJECTED = "supply-provisioning-rejected"

    CAMPAIGN_TARGETS_BUILT = "campaign-targets-built"
    HOME_VISIT_ROUTE_GENERATED = "home-visit-route-generated"
    HOME_VISIT_ROUTE_PUBLISHED = "home-visit-route-published"
    VISIT_ROUTE_SUPPLIES_RESERVED = "visit-route-supplies-reserved"
    VISIT_ROUTE_SUPPLIES_DISPATCHED = "visit-route-supplies-dispatched"

    REFERENCE_RELEASE_PUBLISHED = "reference-release-published"

    ALL = [
      DOMAIN_OUTBOX,
      CLINICAL_RECORD_IMPORTED,
      CLINICAL_RECORD_VALIDATED,
      CLINICAL_RECORD_VALIDATION_FAILED,
      CLINICAL_RECORD_PERSISTED,
      LEDI_BATCH_SUBMITTED,
      LEDI_BATCH_STATUSCHANGED,
      APPOINTMENT_BOOKED,
      APPOINTMENT_WALK_IN_BOOKED,
      APPOINTMENT_RESCHEDULED,
      APPOINTMENT_CHECKEDIN,
      APPOINTMENT_COMPLETED,
      APPOINTMENT_CANCELLED,
      APPOINTMENT_NOSHOW,
      INDICATOR_GAP_DETECTED,
      INDICATOR_TEAM_SCORE_UPDATED,
      CITIZEN_REGISTERED,
      CITIZEN_UPDATED,
      CARE_TEAM_CREATED,
      CARE_TEAM_UPDATED,
      VACCINATION_CAMPAIGN_PUBLISHED,
      VACCINATION_CAMPAIGN_DRAFT_INVALIDATED,
      VACCINATION_PROVISIONING_APPROVED,
      IMMUNOBIOLOGICAL_LOT_RECEIVED,
      SUPPLY_PROVISIONING_REJECTED,
      CAMPAIGN_TARGETS_BUILT,
      HOME_VISIT_ROUTE_GENERATED,
      HOME_VISIT_ROUTE_PUBLISHED,
      VISIT_ROUTE_SUPPLIES_RESERVED,
      VISIT_ROUTE_SUPPLIES_DISPATCHED,
      REFERENCE_RELEASE_PUBLISHED
    ].freeze

    EVENT_TO_TOPIC = ALL.index_by { |name| name }.freeze

    ROUTED = [
      CLINICAL_RECORD_PERSISTED,
      LEDI_BATCH_SUBMITTED,
      LEDI_BATCH_STATUSCHANGED,
      APPOINTMENT_BOOKED,
      APPOINTMENT_WALK_IN_BOOKED,
      APPOINTMENT_CHECKEDIN,
      APPOINTMENT_RESCHEDULED,
      APPOINTMENT_COMPLETED,
      APPOINTMENT_CANCELLED,
      APPOINTMENT_NOSHOW,
      INDICATOR_GAP_DETECTED,
      INDICATOR_TEAM_SCORE_UPDATED,
      CITIZEN_REGISTERED,
      DOMAIN_OUTBOX,
      REFERENCE_RELEASE_PUBLISHED
    ].freeze

    def self.topic_for(event_type)
      EVENT_TO_TOPIC.fetch(event_type)
    end
  end
end
