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

ActiveRecord::Schema[8.1].define(version: 2026_05_27_120018) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"
  enable_extension "postgis"

  create_table "care_teams", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "health_facility_id", null: false
    t.string "ine", null: false
    t.uuid "municipality_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["health_facility_id"], name: "index_care_teams_on_health_facility_id"
    t.index ["municipality_id", "ine"], name: "index_care_teams_on_municipality_id_and_ine", unique: true
    t.index ["municipality_id"], name: "index_care_teams_on_municipality_id"
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
    t.index ["municipality_id", "clinical_record_id", "clinical_record_item_id"], name: "index_encounters_on_municipality_and_clinical_refs", unique: true
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
    t.geography "location"
    t.string "micro_area_code"
    t.uuid "municipality_id", null: false
    t.string "neighborhood"
    t.string "postal_code"
    t.string "street"
    t.string "street_number"
    t.datetime "updated_at", null: false
    t.index ["municipality_id", "clinical_record_id"], name: "index_households_on_municipality_and_clinical_record", unique: true
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
    t.text "last_error"
    t.uuid "municipality_id", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "published_at"
    t.string "status", default: "pending", null: false
    t.string "topic", null: false
    t.datetime "updated_at", null: false
    t.index ["domain_event_id"], name: "index_outbox_messages_on_domain_event_id", unique: true
    t.index ["municipality_id"], name: "index_outbox_messages_on_municipality_id"
    t.index ["status"], name: "index_outbox_messages_on_status"
  end

  create_table "roles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_roles_on_code", unique: true
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

  add_foreign_key "care_teams", "health_facilities"
  add_foreign_key "care_teams", "municipalities"
  add_foreign_key "health_facilities", "municipalities"
  add_foreign_key "user_municipality_memberships", "health_facilities"
  add_foreign_key "user_municipality_memberships", "municipalities"
  add_foreign_key "user_municipality_memberships", "users"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
  add_foreign_key "user_team_assignments", "care_teams"
  add_foreign_key "user_team_assignments", "users"
end
