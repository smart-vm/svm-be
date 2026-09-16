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

ActiveRecord::Schema[8.1].define(version: 2026_09_16_054045) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

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

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "slots", "machines"
  add_foreign_key "slots", "products"
  add_foreign_key "transactions", "machines"
  add_foreign_key "transactions", "slots"
end
