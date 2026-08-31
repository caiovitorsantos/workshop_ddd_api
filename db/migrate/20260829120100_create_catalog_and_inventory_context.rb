# Bounded contexts: Catalog (services offered) and Inventory (parts and
# consumables).
#
# Money is stored in cents (bigint) and never as a float: `price * quantity` has
# to add up to the cent on a quote the customer legally approved.
class CreateCatalogAndInventoryContext < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.string  :name,        null: false
      t.text    :description
      t.bigint  :price_cents, null: false, default: 0
      t.integer :estimated_minutes
      t.boolean :active,      null: false, default: true

      t.timestamps
    end

    add_index :services, :name, unique: true

    create_table :parts do |t|
      t.string  :sku,         null: false, limit: 40
      t.string  :description, null: false
      t.bigint  :price_cents,      null: false, default: 0
      t.integer :quantity_on_hand, null: false, default: 0
      t.integer :minimum_stock,    null: false, default: 0

      t.timestamps
    end

    add_index :parts, :sku, unique: true

    # Movement history: where each part came from and which order consumed it.
    create_table :stock_movements do |t|
      t.references :part, null: false, foreign_key: true
      t.bigint     :service_order_id
      t.string     :kind,       null: false, limit: 10 # deduction | restock
      t.integer    :quantity,   null: false
      t.datetime   :occurred_at, null: false

      t.timestamps
    end

    add_index :stock_movements, :service_order_id

    # The core invariant of the Inventory context, enforced in the database too.
    add_check_constraint :parts, "quantity_on_hand >= 0", name: "stock_never_negative"
    add_check_constraint :parts, "minimum_stock >= 0",    name: "minimum_stock_not_negative"
    add_check_constraint :parts, "price_cents >= 0",      name: "part_price_not_negative"
    add_check_constraint :services, "price_cents >= 0",   name: "service_price_not_negative"
    add_check_constraint :stock_movements, "quantity > 0",
                         name: "stock_movement_quantity_positive"
    add_check_constraint :stock_movements, "kind IN ('deduction', 'restock')",
                         name: "stock_movement_kind_is_known"
  end
end
