module Infrastructure
  module Persistence
    module Repositories
      # ActiveRecord adapter for the Domain::Catalog::ServiceRepository port.
      class ServicesInActiveRecord < Domain::Catalog::ServiceRepository
        Record = Records::Service

        def save(service)
          record = service.new_record? ? Record.new : Record.find(service.id)

          record.assign_attributes(
            name: service.name,
            description: service.description,
            price_cents: service.price.cents,
            estimated_minutes: service.estimated_minutes,
            active: service.active?
          )
          record.save!

          to_domain(record)
        end

        def find(id)
          record = Record.find_by(id: id)
          record && to_domain(record)
        end

        def list(page: 1, per_page: 25, active_only: true)
          scope = Record.order(:name)
          scope = scope.where(active: true) if active_only

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
          Domain::Catalog::Service.new(
            id: record.id,
            name: record.name,
            description: record.description,
            price: Domain::Shared::Money.new(cents: record.price_cents),
            estimated_minutes: record.estimated_minutes,
            active: record.active
          )
        end
      end
    end
  end
end
