module Infrastructure
  module Persistence
    module Repositories
      # ActiveRecord adapter for the Domain::Registry::CustomerRepository port.
      #
      # Reference vertical slice: the other repositories follow this shape.
      # The contract is strict — domain entities go in, domain entities come
      # out, never ActiveRecord objects. The translation happens here, and only
      # here.
      class CustomersInActiveRecord < Domain::Registry::CustomerRepository
        Record = Records::Customer

        def save(customer)
          record = customer.new_record? ? Record.new : Record.find(customer.id)

          record.assign_attributes(
            tax_id: customer.tax_id.number,
            tax_id_kind: customer.tax_id.kind.to_s,
            name: customer.name,
            email: customer.email,
            phone: customer.phone
          )
          record.save!

          to_domain(record)
        end

        def find(id)
          record = Record.find_by(id: id)
          record && to_domain(record)
        end

        def find_by_tax_id(tax_id)
          record = Record.find_by(tax_id: tax_id.number)
          record && to_domain(record)
        end

        # Returns [entities, total] so the interface layer can paginate.
        def list(page: 1, per_page: 25, query: nil)
          scope = Record.order(:name)
          scope = filter_by_query(scope, query) if query.present?

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

        # Searches by name or by tax id, accepting a formatted document.
        def filter_by_query(scope, query)
          digits = query.gsub(/\D/, "")
          condition = scope.where("name ILIKE ?", "%#{query}%")
          condition = condition.or(scope.where("tax_id LIKE ?", "#{digits}%")) if digits.present?
          condition
        end

        # Record -> Entity. The entity revalidates itself on construction, so
        # corrupted data in the database fails loudly instead of silently
        # flowing through the system.
        def to_domain(record)
          Domain::Registry::Customer.new(
            id: record.id,
            tax_id: Domain::Registry::TaxId.parse(record.tax_id),
            name: record.name,
            email: record.email,
            phone: record.phone
          )
        end
      end
    end
  end
end
