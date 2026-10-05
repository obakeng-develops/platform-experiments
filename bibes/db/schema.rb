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

ActiveRecord::Schema[8.1].define(version: 2026_10_05_113928) do
  create_table "bibe_services", force: :cascade do |t|
    t.string "version"
    t.boolean "pinned"
    t.integer "bibe_id", null: false
    t.integer "service_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bibe_id"], name: "index_bibe_services_on_bibe_id"
    t.index ["service_id"], name: "index_bibe_services_on_service_id"
  end

  create_table "bibes", force: :cascade do |t|
    t.string "name"
    t.string "engineer"
    t.string "namespace"
    t.string "environment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "environments", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "releases", force: :cascade do |t|
    t.string "version"
    t.integer "environment_id", null: false
    t.integer "service_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["environment_id"], name: "index_releases_on_environment_id"
    t.index ["service_id"], name: "index_releases_on_service_id"
  end

  create_table "services", force: :cascade do |t|
    t.string "name"
    t.string "kind"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "bibe_services", "bibes"
  add_foreign_key "bibe_services", "services"
  add_foreign_key "releases", "environments"
  add_foreign_key "releases", "services"
end
