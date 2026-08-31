# Bounded context: Registry (customers and vehicles).
#
# The invariants the domain already enforces in memory are repeated here as
# database constraints. That is not distrust of the code: it is the last line of
# defence against writes that bypass the application — data loads, console
# sessions, future data migrations.
class CreateRegistryContext < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      # Stored as digits only; formatting is the value object's job.
      t.string :tax_id,      null: false, limit: 14
      t.string :tax_id_kind, null: false, limit: 4
      t.string :name,        null: false
      t.string :email
      t.string :phone, limit: 20

      t.timestamps
    end

    add_index :customers, :tax_id, unique: true
    add_index :customers, :name

    create_table :vehicles do |t|
      t.string     :plate, null: false, limit: 7
      t.string     :make,  null: false
      t.string     :model, null: false
      t.integer    :year,  null: false
      t.references :customer, null: false, foreign_key: true

      t.timestamps
    end

    add_index :vehicles, :plate, unique: true

    add_check_constraint :customers, "char_length(tax_id) IN (11, 14)",
                         name: "tax_id_has_cpf_or_cnpj_length"
    add_check_constraint :customers, "tax_id_kind IN ('cpf', 'cnpj')",
                         name: "tax_id_kind_is_known"
    add_check_constraint :vehicles, "year BETWEEN 1900 AND 2200",
                         name: "vehicle_year_is_plausible"
  end
end
