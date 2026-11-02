module Application
  module Workshop
    # Use case: the customer arrives at the counter and the order is opened.
    #
    # This is **pivotal event 1** (PLANO_TECH_CHALLENGE.md §2.5): the point where
    # the conversation stops being about people and cars and starts being about
    # work to be done.
    #
    # One request carries everything the counter knows — who, which car, which
    # services, which parts — so this crosses three bounded contexts (Registry,
    # Workshop, Inventory) in one unit of work. Any refusal rolls all of it
    # back: no customer, vehicle, order or reservation is left behind.
    #
    #   * the customer is found by tax id, or registered; an existing one is
    #     used as is (contact details change through UpdateCustomerContact);
    #   * the vehicle is found by plate, or registered under that customer; a
    #     plate owned by someone else is refused — ownership transfer was
    #     removed on purpose in Phase 1;
    #   * parts are locked in ascending id order and reserved per part, not per
    #     line — the same rules as ApproveQuote (see QuotedPartQuantities).
    class OpenServiceOrder < Application::Shared::UseCase
      include QuotedPartQuantities

      Errors = Domain::Shared::Errors

      def initialize(orders:, customers:, vehicles:, services:, parts:, transaction:, events:)
        @orders = orders
        @customers = customers
        @vehicles = vehicles
        @services = services
        @parts = parts
        @transaction = transaction
        @events = events
      end

      private

      attr_reader :orders, :customers, :vehicles, :services, :parts, :transaction, :events

      def perform(customer:, vehicle:, services: [], parts: [])
        order, stock, saved = transaction.within do
          owner = customer_for(**customer)
          car   = vehicle_for(owner, **vehicle)

          order = Domain::Workshop::ServiceOrder.open(
            number: orders.next_number, customer_id: owner.id, vehicle_id: car.id
          )
          services.each { |line| add_service(order, **line) }

          stock = lock_parts(parts.map { |line| line[:part_id] })
          parts.each { |line| add_part(order, stock, **line) }

          # Reserving needs the order's id, so the order is saved first; the
          # unit of work still takes both back if a part is short.
          saved = orders.save(order)
          quantities_by_part(order).each do |part_id, quantity|
            @parts.save(stock.fetch(part_id).reserve!(quantity, service_order_id: saved.id))
          end

          [ order, stock.values, saved ]
        end

        publish_events_of(order, *stock)
        saved
      end

      def customer_for(tax_id: nil, name: nil, email: nil, phone: nil)
        document = Domain::Registry::TaxId.parse(tax_id)

        customers.find_by_tax_id(document) || customers.save(
          Domain::Registry::Customer.new(tax_id: document, name: name, email: email, phone: phone)
        )
      end

      def vehicle_for(owner, plate: nil, make: nil, model: nil, year: nil)
        registration = Domain::Registry::LicensePlate.parse(plate)
        existing = vehicles.find_by_plate(registration)

        if existing && existing.customer_id != owner.id
          raise Errors::AlreadyExists,
                "plate #{registration.formatted} is registered to another customer"
        end

        existing || vehicles.save(
          Domain::Registry::Vehicle.new(
            plate: registration, make: make, model: model, year: year, customer_id: owner.id
          )
        )
      end

      def add_service(order, service_id: nil, quantity: 1)
        service = services.find(service_id)
        raise Errors::NotFound, "service #{service_id} not found" if service.nil?
        raise Errors::BusinessRuleViolation, "service '#{service.name}' is no longer offered" unless service.active?

        order.add_service(
          service_id: service.id, description: service.name,
          unit_price: service.price, quantity: quantity
        )
      end

      # Ascending id order, or two openings sharing two parts can deadlock.
      def lock_parts(part_ids)
        part_ids.map(&:to_i).uniq.sort.to_h do |part_id|
          part = parts.find_for_update(part_id)
          raise Errors::NotFound, "part #{part_id} not found" if part.nil?

          [ part_id, part ]
        end
      end

      def add_part(order, stock, part_id: nil, quantity: nil)
        part = stock.fetch(part_id.to_i)
        order.add_part(
          part_id: part.id, description: part.description,
          unit_price: part.unit_price, quantity: quantity
        )
      end
    end
  end
end
