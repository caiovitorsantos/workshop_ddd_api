# The counter behind the human-facing service order number.
#
# Why not `count + 1`: two orders opened at the same instant read the same count
# and claim the same number.
#
# Why not the primary key: the number is printed, read out over the phone and
# used by the customer to track the order. It belongs to the domain, and tying
# it to a physical row id means it changes if the table is ever rebuilt.
#
# Why a table and not a PostgreSQL sequence — two reasons, and the second is the
# one that matters:
#
#   1. Sequences created in raw SQL are invisible to `schema.rb`, so the test
#      database (loaded from the schema, not from migrations) would not have it.
#      Switching to `structure.sql` would fix that but requires `pg_dump` on
#      every developer's machine, which the no-Docker path in the README does
#      not assume.
#   2. Sequences deliberately leak values on rollback: an order that fails to
#      open still burns its number, leaving OS-000001 followed by OS-000003.
#      A counter row is transactional, so numbering stays gapless — which is
#      what people expect from a document they quote to a customer.
#
# The upsert in ServiceOrdersInActiveRecord#next_number takes a row lock, so
# concurrent opens serialise and each gets a distinct number. The lock is held
# for one tiny statement, and orders are opened at human speed.
#
# The counter row is deliberately NOT seeded here: a migration's INSERT never
# reaches `schema.rb`, so a database loaded from the schema — every test run,
# every fresh checkout — would start with no row to increment. The repository
# seeds it on first use instead.
class AddServiceOrderNumberCounter < ActiveRecord::Migration[8.1]
  def change
    create_table :counters, id: false do |t|
      t.string :name,  null: false, primary_key: true
      t.bigint :value, null: false, default: 0
    end
  end
end
