# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_28_160000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"
  enable_extension "postgis"

  create_table "appointment_room_slots", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "appointment_id"
    t.datetime "created_at", null: false
    t.uuid "health_facility_id", null: false
    t.uuid "municipality_id", null: false
    t.uuid "room_capacity_slot_id", null: false
    t.string "status", default: "available", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_id"], name: "index_appointment_room_slots_on_appointment_id", unique: true, where: "(appointment_id IS NOT NULL)"
    t.index ["room_capacity_slot_id"], name: "index_appointment_room_slots_on_room_capacity_slot_id"
  end

  create_table "appointment_service_types", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.integer "default_duration_minutes", default: 20, null: false
    t.uuid "municipality_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["municipality_id", "code"], name: "index_appointment_service_types_on_municipality_id_and_code", unique: true
  end

  create_table "appointment_waitlist_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "appointment_service_type_id", null: false
    t.uuid "citizen_id", null: false
    t.datetime "created_at", null: false
    t.uuid "health_facility_id", null: false
    t.uuid "municipality_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "status", default: "waiting", null: false
    t.datetime "updated_at", null: false
  end

  create_table "appointments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "appointment_service_type_id", null: false
    t.uuid "care_team_id"
    t.string "channel", default: "web_reception", null: false
    t.uuid "citizen_id", null: false
    t.uuid "consultation_room_id", null: false
    t.datetime "created_at", null: false
    t.integer "duration_minutes", default: 20, null: false
    t.uuid "health_facility_id", null: false
    t.string "kind", default: "scheduled", null: false
    t.string "modality", default: "in_person", null: false
    t.uuid "municipality_id", null: false
    t.uuid "professional_id"
    t.datetime "scheduled_at", null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "updated_at", null: false
    t.index ["health_facility_id", "status", "scheduled_at"], name: "idx_on_health_facility_id_status_scheduled_at_ef6560721a"
    t.index ["municipality_id", "scheduled_at"], name: "index_appointments_on_municipality_id_and_scheduled_at"
  end

  create_table "campaign_targets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "campaign_id", null: false
    t.string "campaign_type", null: false
    t.uuid "citizen_id", null: false
    t.datetime "created_at", null: false
    t.uuid "health_facility_id", null: false
    t.uuid "household_id"
    t.uuid "municipality_id", null: false
    t.integer "priority_score", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_type", "campaign_id", "citizen_id"], name: "index_campaign_targets_on_campaign_citizen", unique: true
    t.index ["campaign_type", "campaign_id", "status"], name: "index_campaign_targets_on_campaign_status"
  end

  create_table "care_teams", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "health_facility_id", null: false
    t.string "ine", null: false
    t.uuid "municipality_id", null: false
    t.string "name", null: false
    t.string "team_kind"
    t.datetime "updated_at", null: false
    t.index ["health_facility_id"], name: "index_care_teams_on_health_facility_id"
    t.index ["municipality_id", "ine"], name: "index_care_teams_on_municipality_id_and_ine", unique: true
    t.index ["municipality_id"], name: "index_care_teams_on_municipality_id"
    t.index ["team_kind"], name: "index_care_teams_on_team_kind"
  end

  create_table "citizen_accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.uuid "citizen_id", null: false
    t.string "cpf", null: false
    t.datetime "created_at", null: false
    t.uuid "municipality_id", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["citizen_id"], name: "index_citizen_accounts_on_citizen_id", unique: true
    t.index ["municipality_id", "cpf"], name: "index_citizen_accounts_on_municipality_id_and_cpf", unique: true
  end

  create_table "citizen_immunization_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "applied_on"
    t.uuid "citizen_id", null: false
    t.datetime "created_at", null: false
    t.string "dose_label"
    t.string "lot_number"
    t.uuid "municipality_id", null: false
    t.string "source", default: "fv_projection", null: false
    t.datetime "updated_at", null: false
    t.string "vaccine_code", null: false
    t.string "vaccine_name", null: false
    t.index ["citizen_id", "vaccine_code", "dose_label"], name: "index_citizen_immunization_on_citizen_vaccine_dose"
  end

  create_table "citizen_indicator_gaps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "care_team_id"
    t.uuid "citizen_id", null: false
    t.datetime "created_at", null: false
    t.date "due_on"
    t.string "good_practice_code"
    t.string "indicator_code", null: false
    t.uuid "municipality_id", null: false
    t.string "status", default: "open", null: false
    t.datetime "updated_at", null: false
    t.index "citizen_id, indicator_code, COALESCE(good_practice_code, ''::character varying)", name: "index_citizen_indicator_gaps_open_unique", unique: true, where: "((status)::text = 'open'::text)"
    t.index ["citizen_id", "indicator_code", "good_practice_code"], name: "index_citizen_indicator_gaps_on_citizen_indicator_bp"
    t.index ["municipality_id", "indicator_code", "status"], name: "index_citizen_indicator_gaps_on_municipality_indicator_status"
  end

  create_table "citizens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "birth_date"
    t.uuid "care_team_id"
    t.uuid "clinical_record_id"
    t.string "cns"
    t.string "cpf"
    t.datetime "created_at", null: false
    t.string "full_name"
    t.uuid "health_facility_id"
    t.uuid "municipality_id", null: false
    t.string "sex"
    t.datetime "updated_at", null: false
    t.index ["municipality_id", "cns"], name: "index_citizens_on_municipality_and_cns", unique: true, where: "(cns IS NOT NULL)"
    t.index ["municipality_id", "cpf"], name: "index_citizens_on_municipality_and_cpf", unique: true, where: "(cpf IS NOT NULL)"
  end

  create_table "clinical_record_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "citizen_cns"
    t.string "citizen_cpf"
    t.uuid "clinical_record_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "payload_json", default: {}, null: false
    t.integer "sequence", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["clinical_record_id", "sequence"], name: "index_clinical_record_items_on_record_and_sequence", unique: true
  end

  create_table "clinical_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "care_team_id"
    t.string "cnes"
    t.datetime "created_at", null: false
    t.datetime "encounter_at"
    t.uuid "health_facility_id"
    t.string "ibge_code"
    t.uuid "municipality_id", null: false
    t.uuid "originator_record_uuid"
    t.jsonb "payload_json", default: {}, null: false
    t.string "payload_schema_version", null: false
    t.string "professional_cns"
    t.string "record_type", null: false
    t.uuid "record_uuid", null: false
    t.uuid "transport_record_id", null: false
    t.datetime "updated_at", null: false
    t.jsonb "validation_errors", default: [], null: false
    t.string "validation_status", default: "pending", null: false
    t.index ["municipality_id", "record_uuid"], name: "index_clinical_records_on_municipality_and_record_uuid", unique: true
    t.index ["record_type"], name: "index_clinical_records_on_record_type"
    t.index ["transport_record_id"], name: "index_clinical_records_on_transport_record_id"
  end

  create_table "consultation_rooms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.uuid "health_facility_id", null: false
    t.uuid "municipality_id", null: false
    t.string "name", null: false
    t.string "room_kind", default: "general", null: false
    t.datetime "updated_at", null: false
    t.index ["municipality_id", "health_facility_id", "name"], name: "index_consultation_rooms_on_facility_and_name", unique: true
  end

  create_table "domain_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "aggregate_id", null: false
    t.string "aggregate_type", null: false
    t.uuid "care_team_id"
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.uuid "health_facility_id"
    t.jsonb "metadata", default: {}, null: false
    t.uuid "municipality_id", null: false
    t.datetime "occurred_at", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "updated_at", null: false
    t.bigint "version", null: false
    t.index ["aggregate_type", "aggregate_id", "version"], name: "index_domain_events_on_aggregate_version", unique: true
    t.index ["event_type"], name: "index_domain_events_on_event_type"
    t.index ["municipality_id"], name: "index_domain_events_on_municipality_id"
    t.index ["occurred_at"], name: "index_domain_events_on_occurred_at"
  end

  create_table "encounters", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "appointment_id"
    t.uuid "care_team_id"
    t.uuid "citizen_id"
    t.uuid "clinical_record_id"
    t.uuid "clinical_record_item_id"
    t.datetime "created_at", null: false
    t.datetime "encounter_at", null: false
    t.uuid "health_facility_id"
    t.uuid "municipality_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_id"], name: "index_encounters_on_appointment_id"
    t.index ["municipality_id", "clinical_record_id", "clinical_record_item_id"], name: "index_encounters_on_municipality_and_clinical_refs", unique: true
  end

  create_table "facility_micro_area_coverages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "health_facility_id", null: false
    t.uuid "micro_area_id", null: false
    t.datetime "updated_at", null: false
    t.index ["health_facility_id", "micro_area_id"], name: "index_facility_micro_area_coverages_on_facility_and_area", unique: true
    t.index ["health_facility_id"], name: "index_facility_micro_area_coverages_on_health_facility_id"
    t.index ["micro_area_id"], name: "index_facility_micro_area_coverages_on_micro_area_id"
  end

  create_table "health_facilities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "cnes", null: false
    t.datetime "created_at", null: false
    t.string "facility_service_kind", default: "primary_care", null: false
    t.uuid "municipality_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["municipality_id", "cnes"], name: "index_health_facilities_on_municipality_id_and_cnes", unique: true
    t.index ["municipality_id"], name: "index_health_facilities_on_municipality_id"
  end

  create_table "home_visit_campaign_provisionings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "health_facility_id", null: false
    t.uuid "home_visit_campaign_id", null: false
    t.uuid "municipality_id", null: false
    t.string "status", default: "draft", null: false
    t.jsonb "totals_json", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["home_visit_campaign_id"], name: "index_home_visit_campaign_provisionings_on_campaign", unique: true
  end

  create_table "home_visit_campaigns", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "ends_on", null: false
    t.uuid "health_facility_id", null: false
    t.uuid "municipality_id", null: false
    t.string "name", null: false
    t.date "starts_on", null: false
    t.string "status", default: "draft", null: false
    t.jsonb "supply_plan", default: [], null: false
    t.jsonb "target_audience_definition", default: {}, null: false
    t.datetime "updated_at", null: false
    t.decimal "waste_factor", precision: 5, scale: 4, default: "0.0", null: false
    t.index ["municipality_id", "health_facility_id", "status"], name: "index_home_visit_campaigns_on_municipality_facility_status"
  end

  create_table "household_animals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "household_id", null: false
    t.string "notes"
    t.integer "quantity", default: 1, null: false
    t.string "species", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id", "species"], name: "index_household_animals_on_household_id_and_species"
    t.index ["household_id"], name: "index_household_animals_on_household_id"
  end

  create_table "household_members", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "citizen_id", null: false
    t.datetime "created_at", null: false
    t.boolean "family_reference", default: false, null: false
    t.uuid "household_id", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id", "citizen_id"], name: "index_household_members_on_household_and_citizen", unique: true
  end

  create_table "households", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "care_team_id"
    t.uuid "clinical_record_id"
    t.string "complement"
    t.datetime "created_at", null: false
    t.uuid "health_facility_id"
    t.string "ibge_code", null: false
    t.st_point "location", geographic: true
    t.string "micro_area_code"
    t.uuid "municipality_id", null: false
    t.string "neighborhood"
    t.string "postal_code"
    t.string "street"
    t.string "street_number"
    t.datetime "updated_at", null: false
    t.index ["location"], name: "index_households_on_location", using: :gist
    t.index ["municipality_id", "clinical_record_id"], name: "index_households_on_municipality_and_clinical_record", unique: true
  end

  create_table "immunobiological_lots", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "expires_on", null: false
    t.uuid "health_facility_id", null: false
    t.uuid "immunobiological_product_id", null: false
    t.string "lot_number", null: false
    t.string "manufacturer"
    t.uuid "municipality_id", null: false
    t.decimal "quantity_on_hand", precision: 12, scale: 3, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["health_facility_id", "immunobiological_product_id", "expires_on"], name: "index_immunobiological_lots_on_facility_product_expires"
    t.index ["health_facility_id", "immunobiological_product_id", "lot_number"], name: "index_immunobiological_lots_on_facility_product_lot", unique: true
  end

  create_table "immunobiological_products", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.uuid "municipality_id", null: false
    t.string "name", null: false
    t.string "target_species", default: "human", null: false
    t.datetime "updated_at", null: false
    t.index ["municipality_id", "code"], name: "index_immunobiological_products_on_municipality_code", unique: true
  end

  create_table "indicator_catalog", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.integer "display_order", default: 0, null: false
    t.string "funding_component", null: false
    t.string "methodology_version", default: "3493/2024", null: false
    t.string "name", null: false
    t.string "periodicity", default: "quarterly", null: false
    t.string "team_kind"
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_indicator_catalog_on_code", unique: true
  end

  create_table "indicator_rules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "expression", default: {}, null: false
    t.uuid "indicator_catalog_id", null: false
    t.string "rule_code", null: false
    t.string "rule_kind", default: "good_practice", null: false
    t.datetime "updated_at", null: false
    t.index ["indicator_catalog_id", "rule_code"], name: "index_indicator_rules_on_catalog_and_code", unique: true
    t.index ["indicator_catalog_id"], name: "index_indicator_rules_on_indicator_catalog_id"
  end

  create_table "installations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "counter_key", null: false
    t.datetime "created_at", null: false
    t.uuid "installation_uuid", null: false
    t.string "legal_name", null: false
    t.uuid "municipality_id", null: false
    t.string "tax_id", null: false
    t.datetime "updated_at", null: false
    t.index ["municipality_id", "counter_key"], name: "index_installations_on_municipality_and_counter_key", unique: true
    t.index ["municipality_id", "installation_uuid"], name: "index_installations_on_municipality_and_uuid", unique: true
  end

  create_table "kafka_processed_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "consumer_group", null: false
    t.datetime "created_at", null: false
    t.uuid "event_id", null: false
    t.datetime "processed_at", null: false
    t.string "topic", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "topic", "consumer_group"], name: "index_kafka_processed_events_on_idempotency", unique: true
  end

  create_table "ledi_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "batch_number", null: false
    t.uuid "care_team_id"
    t.datetime "created_at", null: false
    t.uuid "health_facility_id"
    t.string "ledi_version", null: false
    t.uuid "municipality_id", null: false
    t.datetime "rejected_at"
    t.text "rejection_reason"
    t.string "status", default: "draft", null: false
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.index ["care_team_id"], name: "index_ledi_batches_on_care_team_id"
    t.index ["health_facility_id"], name: "index_ledi_batches_on_health_facility_id"
    t.index ["municipality_id", "batch_number"], name: "index_ledi_batches_on_municipality_batch_number", unique: true, where: "((health_facility_id IS NULL) AND (care_team_id IS NULL))"
    t.index ["municipality_id", "care_team_id", "batch_number"], name: "index_ledi_batches_on_municipality_team_batch_number", unique: true, where: "(care_team_id IS NOT NULL)"
    t.index ["municipality_id", "health_facility_id", "batch_number"], name: "index_ledi_batches_on_municipality_facility_batch_number", unique: true, where: "((health_facility_id IS NOT NULL) AND (care_team_id IS NULL))"
    t.index ["status"], name: "index_ledi_batches_on_status"
  end

  create_table "ledi_field_catalog", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "data_type", null: false
    t.string "field_path", null: false
    t.string "ledi_version", null: false
    t.integer "max_occurs"
    t.integer "min_occurs", default: 0, null: false
    t.string "record_type", null: false
    t.boolean "required", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "field_path", "ledi_version"], name: "index_ledi_field_catalog_on_type_path_version", unique: true
  end

  create_table "ledi_validation_rules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "expression", default: {}, null: false
    t.string "ledi_version", null: false
    t.string "record_type", null: false
    t.string "rule_code", null: false
    t.string "severity", default: "error", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "rule_code", "ledi_version"], name: "index_ledi_validation_rules_on_type_code_version", unique: true
  end

  create_table "micro_areas", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "care_team_id", null: false
    t.string "code", null: false
    t.st_polygon "coverage", geographic: true
    t.datetime "created_at", null: false
    t.uuid "municipality_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["care_team_id"], name: "index_micro_areas_on_care_team_id"
    t.index ["municipality_id", "code"], name: "index_micro_areas_on_municipality_id_and_code", unique: true
    t.index ["municipality_id"], name: "index_micro_areas_on_municipality_id"
  end

  create_table "municipalities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ibge_code", null: false
    t.string "name", null: false
    t.string "state_code", limit: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["ibge_code"], name: "index_municipalities_on_ibge_code", unique: true
  end

  create_table "outbox_messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "domain_event_id", null: false
    t.string "event_type", null: false
    t.uuid "health_facility_id"
    t.datetime "kafka_sent_at"
    t.text "last_error"
    t.uuid "municipality_id", null: false
    t.jsonb "payload", default: {}, null: false
    t.boolean "permanent_failure", default: false, null: false
    t.integer "publish_attempts", default: 0, null: false
    t.datetime "published_at"
    t.datetime "publishing_claimed_at"
    t.string "status", default: "pending", null: false
    t.string "topic", null: false
    t.datetime "updated_at", null: false
    t.index ["domain_event_id"], name: "index_outbox_messages_on_domain_event_id", unique: true
    t.index ["municipality_id"], name: "index_outbox_messages_on_municipality_id"
    t.index ["publishing_claimed_at"], name: "index_outbox_messages_on_publishing_claimed_at", where: "((status)::text = 'publishing'::text)"
    t.index ["status", "permanent_failure", "updated_at"], name: "index_outbox_messages_on_retryable_failed", where: "(((status)::text = 'failed'::text) AND (permanent_failure = false))"
    t.index ["status"], name: "index_outbox_messages_on_status"
  end

  create_table "professional_availability_blocks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ends_at", null: false
    t.uuid "health_facility_id", null: false
    t.uuid "municipality_id", null: false
    t.uuid "professional_id", null: false
    t.string "reason"
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_roles_on_code", unique: true
  end

  create_table "room_capacity_slots", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "booked_count", default: 0, null: false
    t.integer "capacity", default: 1, null: false
    t.uuid "consultation_room_id", null: false
    t.datetime "created_at", null: false
    t.time "ends_at", null: false
    t.uuid "health_facility_id", null: false
    t.uuid "municipality_id", null: false
    t.date "slot_date", null: false
    t.time "starts_at", null: false
    t.datetime "updated_at", null: false
    t.index ["consultation_room_id", "slot_date", "starts_at"], name: "index_room_capacity_slots_on_room_date_start", unique: true
  end

  create_table "stock_balances", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "health_facility_id", null: false
    t.uuid "immunobiological_lot_id"
    t.uuid "municipality_id", null: false
    t.decimal "quantity", precision: 12, scale: 3, default: "0.0", null: false
    t.uuid "supply_item_id"
    t.datetime "updated_at", null: false
    t.index ["health_facility_id", "immunobiological_lot_id"], name: "index_stock_balances_on_facility_lot", unique: true, where: "(immunobiological_lot_id IS NOT NULL)"
    t.index ["health_facility_id", "supply_item_id"], name: "index_stock_balances_on_facility_supply_item", unique: true, where: "(supply_item_id IS NOT NULL)"
  end

  create_table "stock_movements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "health_facility_id", null: false
    t.uuid "immunobiological_lot_id"
    t.string "movement_type", null: false
    t.uuid "municipality_id", null: false
    t.text "notes"
    t.decimal "quantity", precision: 12, scale: 3, null: false
    t.uuid "reference_id"
    t.string "reference_type"
    t.uuid "supply_item_id"
    t.datetime "updated_at", null: false
    t.index ["municipality_id", "health_facility_id", "created_at"], name: "index_stock_movements_on_municipality_facility_created"
  end

  create_table "supply_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.uuid "municipality_id", null: false
    t.string "name", null: false
    t.string "unit", default: "unit", null: false
    t.datetime "updated_at", null: false
    t.index ["municipality_id", "code"], name: "index_supply_items_on_municipality_code", unique: true
  end

  create_table "supply_provisionings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "available_items", default: [], null: false
    t.boolean "capacity_ok", default: true, null: false
    t.datetime "created_at", null: false
    t.uuid "health_facility_id", null: false
    t.uuid "municipality_id", null: false
    t.uuid "provisionable_id", null: false
    t.string "provisionable_type", null: false
    t.text "rejection_reason"
    t.jsonb "required_items", default: [], null: false
    t.jsonb "shortages", default: [], null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["provisionable_type", "provisionable_id"], name: "index_supply_provisionings_on_provisionable", unique: true
  end

  create_table "team_indicator_results", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "care_team_id", null: false
    t.datetime "created_at", null: false
    t.string "indicator_code", null: false
    t.uuid "municipality_id", null: false
    t.decimal "projected_transfer", precision: 12, scale: 2
    t.string "quadrimester", null: false
    t.decimal "score", precision: 5, scale: 2
    t.string "tier"
    t.datetime "updated_at", null: false
    t.index ["care_team_id", "indicator_code", "quadrimester"], name: "index_team_indicator_results_unique", unique: true
  end

  create_table "team_supply_dispatches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "care_team_id", null: false
    t.datetime "created_at", null: false
    t.date "dispatch_date", null: false
    t.uuid "health_facility_id", null: false
    t.jsonb "lines_json", default: [], null: false
    t.uuid "municipality_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["care_team_id", "dispatch_date"], name: "index_team_supply_dispatches_on_team_date", unique: true
  end

  create_table "transport_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "batch_number"
    t.uuid "care_team_id"
    t.string "cnes", null: false
    t.datetime "created_at", null: false
    t.uuid "health_facility_id"
    t.string "ibge_code", null: false
    t.string "ine"
    t.uuid "ledi_batch_id"
    t.string "ledi_version", null: false
    t.uuid "municipality_id", null: false
    t.uuid "origin_health_facility_id"
    t.binary "payload_binary", null: false
    t.bigint "serialized_type", null: false
    t.uuid "serialized_uuid", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["ledi_batch_id"], name: "index_transport_records_on_ledi_batch_id"
    t.index ["municipality_id", "serialized_uuid"], name: "index_transport_records_on_municipality_and_uuid", unique: true
    t.index ["status"], name: "index_transport_records_on_status"
  end

  create_table "user_municipality_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.uuid "health_facility_id"
    t.uuid "municipality_id", null: false
    t.string "role_code", null: false
    t.string "scope", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["health_facility_id"], name: "index_user_municipality_memberships_on_health_facility_id"
    t.index ["municipality_id"], name: "index_user_municipality_memberships_on_municipality_id"
    t.index ["user_id", "municipality_id", "health_facility_id"], name: "index_memberships_on_user_municipality_facility", unique: true
    t.index ["user_id"], name: "index_user_municipality_memberships_on_user_id"
  end

  create_table "user_roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "role_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_roles_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "user_team_assignments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.uuid "care_team_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["care_team_id"], name: "index_user_team_assignments_on_care_team_id"
    t.index ["user_id", "care_team_id"], name: "index_user_team_assignments_on_user_id_and_care_team_id", unique: true
    t.index ["user_id"], name: "index_user_team_assignments_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "full_name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "vaccination_campaigns", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "campaign_kind", default: "human_immunization", null: false
    t.uuid "consultation_room_id"
    t.datetime "created_at", null: false
    t.date "ends_on", null: false
    t.uuid "health_facility_id", null: false
    t.uuid "immunobiological_product_id", null: false
    t.uuid "municipality_id", null: false
    t.string "name", null: false
    t.integer "room_capacity_per_day", default: 0, null: false
    t.date "starts_on", null: false
    t.string "status", default: "draft", null: false
    t.jsonb "target_audience_definition", default: {}, null: false
    t.integer "target_doses", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["consultation_room_id"], name: "index_vaccination_campaigns_on_consultation_room_id"
    t.index ["municipality_id", "health_facility_id", "status"], name: "index_vaccination_campaigns_on_municipality_facility_status"
  end

  create_table "visit_route_provisionings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "health_facility_id", null: false
    t.jsonb "lines_json", default: [], null: false
    t.uuid "municipality_id", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.uuid "visit_route_id", null: false
    t.index ["visit_route_id"], name: "index_visit_route_provisionings_on_route", unique: true
  end

  create_table "visit_route_stops", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "campaign_target_id"
    t.uuid "citizen_id", null: false
    t.datetime "created_at", null: false
    t.uuid "household_id"
    t.uuid "municipality_id", null: false
    t.string "status", default: "pending", null: false
    t.integer "stop_order", null: false
    t.datetime "updated_at", null: false
    t.uuid "visit_route_id", null: false
    t.datetime "visited_at"
    t.index ["visit_route_id", "stop_order"], name: "index_visit_route_stops_on_route_order", unique: true
  end

  create_table "visit_routes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "care_team_id", null: false
    t.datetime "created_at", null: false
    t.uuid "health_facility_id", null: false
    t.uuid "home_visit_campaign_id", null: false
    t.uuid "municipality_id", null: false
    t.date "route_date", null: false
    t.integer "sequence_number", default: 1, null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["home_visit_campaign_id", "care_team_id", "route_date", "sequence_number"], name: "index_visit_routes_on_campaign_team_date_seq", unique: true
  end

  add_foreign_key "care_teams", "health_facilities"
  add_foreign_key "care_teams", "municipalities"
  add_foreign_key "citizen_indicator_gaps", "care_teams"
  add_foreign_key "citizen_indicator_gaps", "citizens"
  add_foreign_key "citizen_indicator_gaps", "municipalities"
  add_foreign_key "encounters", "appointments"
  add_foreign_key "facility_micro_area_coverages", "health_facilities"
  add_foreign_key "facility_micro_area_coverages", "micro_areas"
  add_foreign_key "health_facilities", "municipalities"
  add_foreign_key "home_visit_campaign_provisionings", "home_visit_campaigns"
  add_foreign_key "home_visit_campaigns", "health_facilities"
  add_foreign_key "household_animals", "households"
  add_foreign_key "immunobiological_lots", "health_facilities"
  add_foreign_key "immunobiological_lots", "immunobiological_products"
  add_foreign_key "indicator_rules", "indicator_catalog"
  add_foreign_key "micro_areas", "care_teams"
  add_foreign_key "micro_areas", "municipalities"
  add_foreign_key "stock_balances", "health_facilities"
  add_foreign_key "stock_balances", "immunobiological_lots"
  add_foreign_key "stock_balances", "supply_items"
  add_foreign_key "stock_movements", "health_facilities"
  add_foreign_key "stock_movements", "immunobiological_lots"
  add_foreign_key "stock_movements", "supply_items"
  add_foreign_key "team_indicator_results", "care_teams"
  add_foreign_key "team_indicator_results", "municipalities"
  add_foreign_key "team_supply_dispatches", "care_teams"
  add_foreign_key "user_municipality_memberships", "health_facilities"
  add_foreign_key "user_municipality_memberships", "municipalities"
  add_foreign_key "user_municipality_memberships", "users"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
  add_foreign_key "user_team_assignments", "care_teams"
  add_foreign_key "user_team_assignments", "users"
  add_foreign_key "vaccination_campaigns", "consultation_rooms"
  add_foreign_key "vaccination_campaigns", "health_facilities"
  add_foreign_key "vaccination_campaigns", "immunobiological_products"
  add_foreign_key "visit_route_provisionings", "visit_routes"
  add_foreign_key "visit_route_stops", "visit_routes"
  add_foreign_key "visit_routes", "care_teams"
  add_foreign_key "visit_routes", "home_visit_campaigns"
end
