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

ActiveRecord::Schema[8.1].define(version: 2026_05_27_120007) do
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
  create_table "kafka_processed_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "consumer_group", null: false
    t.datetime "created_at", null: false
    t.uuid "event_id", null: false
    t.datetime "processed_at", null: false
    t.string "topic", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "topic", "consumer_group"], name: "index_kafka_processed_events_on_idempotency", unique: true
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
end
