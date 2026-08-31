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

ActiveRecord::Schema[8.1].define(version: 2026_08_29_140100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "counters", primary_key: "name", id: :string, force: :cascade do |t|
    t.bigint "value", default: 0, null: false
  end

  create_table "customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name", null: false
    t.string "phone", limit: 20
    t.string "tax_id", limit: 14, null: false
    t.string "tax_id_kind", limit: 4, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_customers_on_name"
    t.index ["tax_id"], name: "index_customers_on_tax_id", unique: true
    t.check_constraint "char_length(tax_id::text) = ANY (ARRAY[11, 14])", name: "tax_id_has_cpf_or_cnpj_length"
    t.check_constraint "tax_id_kind::text = ANY (ARRAY['cpf'::character varying::text, 'cnpj'::character varying::text])", name: "tax_id_kind_is_known"
  end

  create_table "part_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.bigint "part_id", null: false
    t.integer "quantity", null: false
    t.bigint "service_order_id", null: false
    t.bigint "unit_price_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["service_order_id"], name: "index_part_items_on_service_order_id"
    t.check_constraint "quantity > 0", name: "part_item_quantity_positive"
  end

  create_table "parts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.integer "minimum_stock", default: 0, null: false
    t.bigint "price_cents", default: 0, null: false
    t.integer "quantity_on_hand", default: 0, null: false
    t.string "sku", limit: 40, null: false
    t.datetime "updated_at", null: false
    t.index ["sku"], name: "index_parts_on_sku", unique: true
    t.check_constraint "minimum_stock >= 0", name: "minimum_stock_not_negative"
    t.check_constraint "price_cents >= 0", name: "part_price_not_negative"
    t.check_constraint "quantity_on_hand >= 0", name: "stock_never_negative"
  end

  create_table "service_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.integer "quantity", default: 1, null: false
    t.bigint "service_id", null: false
    t.bigint "service_order_id", null: false
    t.bigint "unit_price_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["service_order_id"], name: "index_service_items_on_service_order_id"
    t.check_constraint "quantity > 0", name: "service_item_quantity_positive"
  end

  create_table "service_orders", force: :cascade do |t|
    t.datetime "approved_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.datetime "delivered_at"
    t.text "diagnosis"
    t.bigint "labour_total_cents", default: 0, null: false
    t.string "number", limit: 20, null: false
    t.datetime "opened_at", null: false
    t.bigint "parts_total_cents", default: 0, null: false
    t.datetime "quote_generated_at"
    t.datetime "started_at"
    t.string "status", limit: 30, default: "received", null: false
    t.datetime "updated_at", null: false
    t.bigint "vehicle_id", null: false
    t.index ["customer_id"], name: "index_service_orders_on_customer_id"
    t.index ["number"], name: "index_service_orders_on_number", unique: true
    t.index ["opened_at"], name: "index_service_orders_on_opened_at"
    t.index ["status"], name: "index_service_orders_on_status"
    t.index ["vehicle_id"], name: "index_service_orders_on_vehicle_id"
    t.check_constraint "status::text = ANY (ARRAY['received'::character varying::text, 'in_diagnosis'::character varying::text, 'awaiting_approval'::character varying::text, 'in_progress'::character varying::text, 'completed'::character varying::text, 'delivered'::character varying::text, 'cancelled'::character varying::text])", name: "service_order_status_is_known"
  end

  create_table "services", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "estimated_minutes"
    t.string "name", null: false
    t.bigint "price_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_services_on_name", unique: true
    t.check_constraint "price_cents >= 0", name: "service_price_not_negative"
  end

  create_table "stock_movements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", limit: 10, null: false
    t.datetime "occurred_at", null: false
    t.bigint "part_id", null: false
    t.integer "quantity", null: false
    t.bigint "service_order_id"
    t.datetime "updated_at", null: false
    t.index ["part_id"], name: "index_stock_movements_on_part_id"
    t.index ["service_order_id"], name: "index_stock_movements_on_service_order_id"
    t.check_constraint "kind::text = ANY (ARRAY['deduction'::character varying::text, 'restock'::character varying::text])", name: "stock_movement_kind_is_known"
    t.check_constraint "quantity > 0", name: "stock_movement_quantity_positive"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "role", limit: 20, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.check_constraint "role::text = ANY (ARRAY['front_desk'::character varying::text, 'mechanic'::character varying::text, 'manager'::character varying::text])", name: "role_is_known"
  end

  create_table "vehicles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.string "make", null: false
    t.string "model", null: false
    t.string "plate", limit: 7, null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["customer_id"], name: "index_vehicles_on_customer_id"
    t.index ["plate"], name: "index_vehicles_on_plate", unique: true
    t.check_constraint "year >= 1900 AND year <= 2200", name: "vehicle_year_is_plausible"
  end

  add_foreign_key "part_items", "service_orders", on_delete: :cascade
  add_foreign_key "service_items", "service_orders", on_delete: :cascade
  add_foreign_key "service_orders", "customers"
  add_foreign_key "service_orders", "vehicles"
  add_foreign_key "stock_movements", "parts"
  add_foreign_key "vehicles", "customers"
end
