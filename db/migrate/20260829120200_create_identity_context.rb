# Bounded context: Identity and Access (a generic subdomain).
#
# Stores only the BCrypt digest — a plaintext password never touches the
# database or the logs.
class CreateIdentityContext < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string  :name,            null: false
      t.string  :email,           null: false
      t.string  :role,            null: false, limit: 20
      t.string  :password_digest, null: false
      t.boolean :active,          null: false, default: true

      t.timestamps
    end

    add_index :users, :email, unique: true

    add_check_constraint :users,
                         "role IN ('front_desk', 'mechanic', 'manager')",
                         name: "role_is_known"
  end
end
