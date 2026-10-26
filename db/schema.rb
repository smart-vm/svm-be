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

ActiveRecord::Schema[8.1].define(version: 2026_10_26_090000) do
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

  create_table "advertisement_machines", force: :cascade do |t|
    t.bigint "advertisement_id", null: false
    t.datetime "created_at", null: false
    t.bigint "machine_id", null: false
    t.datetime "updated_at", null: false
    t.index ["advertisement_id", "machine_id"], name: "idx_on_advertisement_id_machine_id_04c37c747d", unique: true
    t.index ["advertisement_id"], name: "index_advertisement_machines_on_advertisement_id"
    t.index ["machine_id"], name: "index_advertisement_machines_on_machine_id"
  end

  create_table "advertisements", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "duration_seconds", default: 8, null: false
    t.datetime "ends_at"
    t.string "placements", default: [], null: false, array: true
    t.integer "position", default: 0, null: false
    t.datetime "starts_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "position"], name: "index_advertisements_on_active_and_position"
  end

  create_table "machines", force: :cascade do |t|
    t.string "api_token", null: false
    t.datetime "created_at", null: false
    t.datetime "last_heartbeat_at"
    t.string "location_name", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["api_token"], name: "index_machines_on_api_token", unique: true
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

  create_table "stock_batches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", null: false
    t.integer "remaining_quantity", null: false
    t.bigint "slot_id", null: false
    t.datetime "sold_out_at"
    t.integer "sold_quantity", default: 0, null: false
    t.datetime "stocked_at"
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_stock_batches_on_product_id"
    t.index ["slot_id", "id"], name: "index_stock_batches_on_slot_id_and_id"
    t.index ["slot_id"], name: "index_stock_batches_on_slot_id"
    t.check_constraint "quantity > 0 AND remaining_quantity >= 0 AND sold_quantity >= 0 AND (remaining_quantity + sold_quantity) <= quantity", name: "stock_batches_valid_quantities"
  end

  create_table "transactions", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2
    t.jsonb "callback_payload", default: {}, null: false
    t.text "checkout_url"
    t.datetime "created_at", null: false
    t.datetime "dispense_started_at"
    t.datetime "dispensed_at"
    t.datetime "expires_at"
    t.string "external_reference"
    t.string "failure_reason"
    t.decimal "fee", precision: 12, scale: 2
    t.jsonb "gateway_payload", default: {}, null: false
    t.string "issuer_name"
    t.bigint "machine_id", null: false
    t.datetime "paid_at"
    t.string "payment_channel"
    t.string "payment_method"
    t.text "qr_content"
    t.text "qr_image_url"
    t.string "rrn"
    t.bigint "slot_id", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.jsonb "vend_result", default: {}, null: false
    t.index ["machine_id", "status"], name: "index_transactions_on_machine_id_and_status"
    t.index ["machine_id"], name: "index_transactions_on_machine_id"
    t.index ["slot_id"], name: "index_transactions_on_slot_id"
    t.index ["status", "created_at"], name: "index_transactions_on_status_and_created_at"
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
  add_foreign_key "advertisement_machines", "advertisements"
  add_foreign_key "advertisement_machines", "machines"
  add_foreign_key "slots", "machines"
  add_foreign_key "slots", "products"
  add_foreign_key "stock_batches", "products"
  add_foreign_key "stock_batches", "slots"
  add_foreign_key "transactions", "machines"
  add_foreign_key "transactions", "slots"
end
