module Infrastructure
  module Persistence
    module Repositories
      # ActiveRecord adapter for the Domain::Registry::VehicleRepository port.
      class VehiclesInActiveRecord < Domain::Registry::VehicleRepository
        Record = Records::Vehicle

        def save(vehicle)
          record = vehicle.new_record? ? Record.new : Record.find(vehicle.id)

          record.assign_attributes(
            plate: vehicle.plate.code,
            make: vehicle.make,
            model: vehicle.model,
            year: vehicle.year,
            customer_id: vehicle.customer_id
          )
          record.save!

          to_domain(record)
        end

        def find(id)
          record = Record.find_by(id: id)
          record && to_domain(record)
        end

        def find_by_plate(plate)
          record = Record.find_by(plate: plate.code)
          record && to_domain(record)
        end

        def list_for_customer(customer_id)
          Record.where(customer_id: customer_id).order(:plate).map { |r| to_domain(r) }
        end

        def delete(id)
          Record.find_by(id: id)&.destroy!
        end

        private

        def to_domain(record)
          Domain::Registry::Vehicle.new(
            id: record.id,
            plate: Domain::Registry::LicensePlate.parse(record.plate),
            make: record.make,
            model: record.model,
            year: record.year,
            customer_id: record.customer_id
          )
        end
      end
    end
  end
end
