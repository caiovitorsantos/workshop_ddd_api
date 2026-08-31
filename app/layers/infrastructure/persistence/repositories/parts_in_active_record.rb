module Infrastructure
  module Persistence
    module Repositories
      # ActiveRecord adapter for the Domain::Inventory::PartRepository port.
      class PartsInActiveRecord < Domain::Inventory::PartRepository
        Record = Records::Part

        def save(part)
          record = part.new_record? ? Record.new : Record.find(part.id)

          record.assign_attributes(
            sku: part.sku,
            description: part.description,
            price_cents: part.unit_price.cents,
            quantity_on_hand: part.quantity_on_hand,
            quantity_reserved: part.quantity_reserved,
            minimum_stock: part.minimum_stock
          )
          record.save!

          to_domain(record)
        end

        def find(id)
          record = Record.find_by(id: id)
          record && to_domain(record)
        end

        # `lock` issues SELECT ... FOR UPDATE. The lock lives until the
        # surrounding transaction commits or rolls back, which is what makes
        # concurrent quote approvals serialise instead of overselling.
        def find_for_update(id)
          record = Record.lock.find_by(id: id)
          record && to_domain(record)
        end

        def find_by_sku(sku)
          record = Record.find_by(sku: sku.to_s.strip.upcase)
          record && to_domain(record)
        end

        def list(page: 1, per_page: 25, below_minimum: false)
          scope = Record.order(:sku)
          scope = scope.where("quantity_on_hand < minimum_stock") if below_minimum

          total    = scope.count
          page     = [ page.to_i, 1 ].max
          per_page = per_page.to_i.clamp(1, 100)

          records = scope.offset((page - 1) * per_page).limit(per_page)

          [ records.map { |r| to_domain(r) }, total ]
        end

        def delete(id)
          Record.find_by(id: id)&.destroy!
        end

        private

        def to_domain(record)
          Domain::Inventory::Part.new(
            id: record.id,
            sku: record.sku,
            description: record.description,
            unit_price: Domain::Shared::Money.new(cents: record.price_cents),
            quantity_on_hand: record.quantity_on_hand,
            quantity_reserved: record.quantity_reserved,
            minimum_stock: record.minimum_stock
          )
        end
      end
    end
  end
end
