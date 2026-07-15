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

ActiveRecord::Schema[8.1].define(version: 2026_07_15_054419) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "machines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_heartbeat_at"
    t.string "location_name", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["uuid"], name: "index_machines_on_uuid", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "image_url"
    t.string "name"
    t.decimal "price", precision: 12, scale: 2
    t.datetime "updated_at", null: false
  end

  create_table "slots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_stock"
    t.bigint "machine_id", null: false
    t.integer "max_capacity"
    t.bigint "product_id", null: false
    t.integer "slot_number"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["machine_id"], name: "index_slots_on_machine_id"
    t.index ["product_id"], name: "index_slots_on_product_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.string "external_reference"
    t.bigint "machine_id", null: false
    t.bigint "slot_id", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["machine_id"], name: "index_transactions_on_machine_id"
    t.index ["slot_id"], name: "index_transactions_on_slot_id"
    t.index ["uuid"], name: "index_transactions_on_uuid", unique: true
  end

  add_foreign_key "slots", "machines"
  add_foreign_key "slots", "products"
  add_foreign_key "transactions", "machines"
  add_foreign_key "transactions", "slots"
end
