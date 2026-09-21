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

ActiveRecord::Schema[8.1].define(version: 2026_09_18_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ledger_accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "code", null: false
    t.datetime "created_at", null: false
    t.decimal "credits_posted", precision: 39, default: "0", null: false
    t.boolean "debits_must_not_exceed_credits", default: false, null: false
    t.decimal "debits_posted", precision: 39, default: "0", null: false
    t.integer "ledger", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ledger_transfers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "amount", precision: 39, null: false
    t.integer "code", null: false
    t.datetime "created_at", null: false
    t.uuid "credit_account_id", null: false
    t.uuid "debit_account_id", null: false
    t.uuid "event_id", null: false
    t.integer "ledger", null: false
    t.datetime "updated_at", null: false
    t.index ["credit_account_id"], name: "index_ledger_transfers_on_credit_account_id"
    t.index ["debit_account_id"], name: "index_ledger_transfers_on_debit_account_id"
    t.index ["event_id"], name: "index_ledger_transfers_on_event_id"
  end

  create_table "meters", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "reference", null: false
    t.datetime "updated_at", null: false
    t.uuid "utility_id", null: false
    t.index ["utility_id", "reference"], name: "index_meters_on_utility_id_and_reference", unique: true
    t.index ["utility_id"], name: "index_meters_on_utility_id"
  end

  create_table "utilities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "tariff_micros_per_wh", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "meters", "utilities"
end
