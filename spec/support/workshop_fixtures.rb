# Builders for the aggregates a service order needs around it.
#
# They go through the real repositories rather than inserting rows directly, so
# a test scenario cannot be built in a shape the domain would have refused.
module WorkshopFixtures
  def customers = Infrastructure::Persistence::Repositories::CustomersInActiveRecord.new
  def vehicles  = Infrastructure::Persistence::Repositories::VehiclesInActiveRecord.new
  def services  = Infrastructure::Persistence::Repositories::ServicesInActiveRecord.new
  def parts     = Infrastructure::Persistence::Repositories::PartsInActiveRecord.new
  def orders    = Infrastructure::Persistence::Repositories::ServiceOrdersInActiveRecord.new

  # Unique-by-default identifiers.
  #
  # Most specs run inside a transaction that rolls back, so collisions never
  # surface — but the concurrency spec cannot, and there a fixed CPF makes the
  # second customer explode on the unique index. Generating instead of hardcoding
  # keeps every spec independent of how the previous one cleaned up.
  def next_fixture_sequence
    @@fixture_sequence = (defined?(@@fixture_sequence) ? @@fixture_sequence : 0) + 1
  end

  # Builds a CPF that actually passes TaxId's check digits — the domain would
  # reject anything else, so fixtures cannot cheat.
  def generate_cpf(seed = next_fixture_sequence)
    base = format("%09d", seed % 1_000_000_000).chars.map(&:to_i)
    first  = cpf_check_digit(base, 10)
    second = cpf_check_digit(base + [ first ], 11)

    (base + [ first, second ]).join
  end

  def generate_plate(seed = next_fixture_sequence)
    letters = ("A".."Z").to_a
    format(
      "%s%s%s%d%s%02d",
      letters[seed % 26], letters[(seed / 26) % 26], letters[(seed / 676) % 26],
      seed % 10, letters[(seed / 7) % 26], seed % 100
    )
  end

  def create_customer(tax_id: nil, name: "Maria Souza")
    customers.save(
      Domain::Registry::Customer.new(
        tax_id: Domain::Registry::TaxId.parse(tax_id || generate_cpf), name: name
      )
    )
  end

  def create_vehicle(customer: nil, plate: nil)
    customer ||= create_customer
    vehicles.save(
      Domain::Registry::Vehicle.new(
        plate: Domain::Registry::LicensePlate.parse(plate || generate_plate),
        make: "Volkswagen", model: "Gol", year: 2019, customer_id: customer.id
      )
    )
  end

  # Same modulo-11 rule TaxId enforces; duplicated here rather than reaching
  # into the value object's private methods, so a fixture bug cannot be hidden
  # by the same bug in production code.
  def cpf_check_digit(digits, starting_weight)
    sum = digits.each_with_index.sum { |digit, i| digit * (starting_weight - i) }
    remainder = (sum * 10) % 11
    remainder == 10 ? 0 : remainder
  end

  # Name and SKU are unique in the database, so these default to generated
  # values for the same reason CPFs do. Pass an explicit one when the spec is
  # actually about the name.
  def create_service(name: nil, price: 120, active: true)
    services.save(
      Domain::Catalog::Service.new(
        name: name || "Troca de óleo ##{next_fixture_sequence}",
        price: Domain::Shared::Money.from_amount(price),
        estimated_minutes: 30, active: active
      )
    )
  end

  def create_part(sku: nil, price: 45, on_hand: 10, minimum: 2)
    parts.save(
      Domain::Inventory::Part.new(
        sku: sku || "FIL-#{next_fixture_sequence}",
        description: "Filtro de óleo",
        unit_price: Domain::Shared::Money.from_amount(price),
        quantity_on_hand: on_hand, minimum_stock: minimum
      )
    )
  end

  def create_user(email: "gerente@oficina.test", role: :manager, password: "senha-forte-123")
    Infrastructure::Persistence::Repositories::UsersInActiveRecord.new.save(
      Domain::Identity::User.new(
        name: "Gabriela Gerente", email: email, role: role, password_digest: "placeholder"
      ),
      password: password
    )
  end

  # A freshly opened order, still a draft (status `received`).
  def draft_order(vehicle: nil)
    vehicle ||= create_vehicle
    must_succeed(
      Application::Workshop::OpenServiceOrder.call(
        orders: orders, vehicles: vehicles, customers: customers, vehicle_id: vehicle.id
      )
    )
  end

  # A draft with one service on it, moved to `in_diagnosis` — the state
  # `send_quote` acts from.
  def order_in_diagnosis(service: nil)
    order   = draft_order
    service ||= create_service
    must_succeed(
      Application::Workshop::AddServiceToOrder.call(
        orders: orders, services: services, id: order.id, service_id: service.id
      )
    )
    must_succeed(Application::Workshop::StartDiagnosis.call(repository: orders, id: order.id))
  end

  # An approved order, now `in_progress`.
  def order_in_progress(**options)
    order = order_awaiting_approval(**options)
    must_succeed(Application::Workshop::ApproveQuote.call(orders: orders, parts: parts, id: order.id))
  end

  # Work finished, order `completed` and awaiting delivery.
  def order_completed(**options)
    order = order_in_progress(**options)
    must_succeed(Application::Workshop::CompleteWork.call(repository: orders, id: order.id))
  end

  # Walks a fresh order up to the point where the quote is with the customer.
  # Everything after that is what most specs actually want to exercise.
  def order_awaiting_approval(part: nil, part_quantity: 2, service: nil)
    part    ||= create_part
    service ||= create_service
    vehicle   = create_vehicle

    order = must_succeed(
      Application::Workshop::OpenServiceOrder.call(
        orders: orders, vehicles: vehicles, customers: customers, vehicle_id: vehicle.id
      )
    )

    must_succeed(
      Application::Workshop::AddServiceToOrder.call(
        orders: orders, services: services, id: order.id, service_id: service.id
      )
    )
    must_succeed(
      Application::Workshop::AddPartToOrder.call(
        orders: orders, parts: parts, id: order.id, part_id: part.id, quantity: part_quantity
      )
    )
    must_succeed(Application::Workshop::StartDiagnosis.call(repository: orders, id: order.id))
    must_succeed(
      Application::Workshop::SendQuote.call(
        repository: orders, id: order.id, diagnosis: "Óleo vencido e filtro saturado"
      )
    )
  end

  # Use cases return a Result instead of raising, which is right for production
  # and a trap for fixtures: a step that quietly fails leaves the spec asserting
  # against a scenario that was never built. Blow up here instead.
  def must_succeed(result)
    raise "fixture step failed: #{result.error}" if result.failure?

    result.value
  end
end

RSpec.configure do |config|
  config.include WorkshopFixtures
end
