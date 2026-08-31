# Bounded context: Workshop (the core subdomain) — the service order.
#
# The whole aggregate fits in three tables. The item tables cascade on delete
# because items do not exist outside the order: they are internal entities of
# the aggregate, not aggregates of their own.
#
# `service_id` and `part_id` are intentionally weak references — they point at
# aggregates in other contexts, and the description/price are copied into the
# item so that a price change in the catalog cannot rewrite a quote the customer
# already approved.
class CreateWorkshopContext < ActiveRecord::Migration[8.1]
  def change
    create_table :service_orders do |t|
      t.string     :number, null: false, limit: 20
      t.references :customer, null: false, foreign_key: true
      t.references :vehicle,  null: false, foreign_key: true

      t.string :status, null: false, limit: 30, default: "received"
      t.text   :diagnosis

      # Quote (value object) flattened into columns.
      t.bigint   :labour_total_cents, null: false, default: 0
      t.bigint   :parts_total_cents,  null: false, default: 0
      t.datetime :quote_generated_at

      # Life cycle milestones — the raw material of the average execution time.
      t.datetime :opened_at, null: false
      t.datetime :approved_at
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :delivered_at

      t.timestamps
    end

    add_index :service_orders, :number, unique: true
    add_index :service_orders, :status
    add_index :service_orders, :opened_at

    create_table :service_items do |t|
      t.references :service_order, null: false,
                   foreign_key: { on_delete: :cascade }
      t.bigint  :service_id,  null: false
      t.string  :description, null: false
      t.bigint  :unit_price_cents, null: false, default: 0
      t.integer :quantity,    null: false, default: 1

      t.timestamps
    end

    create_table :part_items do |t|
      t.references :service_order, null: false,
                   foreign_key: { on_delete: :cascade }
      t.bigint  :part_id,     null: false
      t.string  :description, null: false
      t.bigint  :unit_price_cents, null: false, default: 0
      t.integer :quantity,    null: false

      t.timestamps
    end

    add_check_constraint :service_orders,
                         "status IN ('received', 'in_diagnosis', 'awaiting_approval', " \
                         "'in_progress', 'completed', 'delivered', 'cancelled')",
                         name: "service_order_status_is_known"
    add_check_constraint :service_items, "quantity > 0", name: "service_item_quantity_positive"
    add_check_constraint :part_items,    "quantity > 0", name: "part_item_quantity_positive"
  end
end
