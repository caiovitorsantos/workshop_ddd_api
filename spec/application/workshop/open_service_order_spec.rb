require "rails_helper"

# Opening an order crosses Registry, Workshop and Inventory in one unit of
# work, so this runs against the real repositories and PostgreSQL: the point
# is what is — and is not — left in the database afterwards.
RSpec.describe Application::Workshop::OpenServiceOrder do
  subject(:use_case) { container.open_service_order }

  Records = Infrastructure::Persistence::Records

  let(:new_customer) { { tax_id: "529.982.247-25", name: "Maria Silva", email: "maria@exemplo.com" } }
  let(:new_vehicle)  { { plate: "ABC1D23", make: "Fiat", model: "Argo", year: 2021 } }

  def open(customer: new_customer, vehicle: new_vehicle, services: [], parts: [])
    use_case.call(customer: customer, vehicle: vehicle, services: services, parts: parts)
  end

  def row_counts
    [ Records::Customer, Records::Vehicle, Records::ServiceOrder ].map(&:count)
  end

  it "registers customer and vehicle on the fly and opens the order with its lines" do
    service = create_service(price: 120)
    part    = create_part(price: 45, on_hand: 10)

    result = open(
      services: [ { service_id: service.id } ],
      parts: [ { part_id: part.id, quantity: 2 } ]
    )

    expect(result).to be_success
    order = orders.find(result.value.id)
    expect(order.status).to be_received
    expect(order.quote.total.amount).to eq(210)
    expect(customers.find(order.customer_id).name).to eq("Maria Silva")
    expect(vehicles.find(order.vehicle_id).plate.code).to eq("ABC1D23")
    expect(parts.find(part.id).quantity_reserved).to eq(2)
  end

  it "reuses a known customer and vehicle as they are, without overwriting them" do
    vehicle = create_vehicle
    input   = opening_of(vehicle)
    input[:customer][:name] = "Outro Nome"

    before = row_counts

    expect(use_case.call(**input)).to be_success
    expect(row_counts).to eq(before.zip([ 0, 0, 1 ]).map(&:sum))
    expect(customers.find(vehicle.customer_id).name).to eq("Maria Souza")
  end

  it "registers a new car under a known customer" do
    owner = create_customer(tax_id: "52998224725")

    result = open(customer: { tax_id: "52998224725" })

    expect(result).to be_success
    expect(vehicles.find(result.value.vehicle_id).customer_id).to eq(owner.id)
  end

  it "refuses a plate that belongs to another customer, and keeps nothing" do
    someone_elses = create_vehicle(plate: "ABC1D23")
    before = row_counts

    result = open

    expect(result).to be_failure
    expect(result.code).to eq(:already_exists)
    expect(row_counts).to eq(before)
    expect(vehicles.find(someone_elses.id).customer_id).not_to be_nil
  end

  it "rolls everything back when a part is short" do
    part = create_part(on_hand: 1)
    before = row_counts

    result = open(parts: [ { part_id: part.id, quantity: 2 } ])

    expect(result.code).to eq(:business_rule_violation)
    expect(row_counts).to eq(before)
    expect(parts.find(part.id).quantity_reserved).to eq(0)
  end

  it "checks stock per part, not per line, when the same part appears twice" do
    part = create_part(on_hand: 3)

    result = open(parts: [ { part_id: part.id, quantity: 2 }, { part_id: part.id, quantity: 2 } ])

    expect(result.code).to eq(:business_rule_violation)
    expect(parts.find(part.id).quantity_reserved).to eq(0)
  end

  it "refuses a retired service" do
    service = create_service(active: false)

    result = open(services: [ { service_id: service.id } ])

    expect(result.code).to eq(:business_rule_violation)
    expect(Records::Customer.count).to eq(0)
  end

  it "reports unknown services and parts as not found" do
    expect(open(services: [ { service_id: 999_999 } ]).code).to eq(:not_found)
    expect(open(parts: [ { part_id: 999_999, quantity: 1 } ]).code).to eq(:not_found)
  end

  it "lets the domain refuse incomplete input" do
    expect(open(customer: { tax_id: "52998224725" }).code).to eq(:invalid_value) # new customer, no name
    expect(open(vehicle: { plate: "ABC1D23" }).code).to eq(:invalid_value)       # new vehicle, no make
  end

  it "announces the opening and the reservation only after the commit" do
    use_case = described_class.new(
      orders: orders, customers: customers, vehicles: vehicles, services: services,
      parts: parts, transaction: transaction, events: events
    )
    part = create_part(on_hand: 5)

    use_case.call(customer: new_customer, vehicle: new_vehicle, parts: [ { part_id: part.id, quantity: 1 } ])

    expect(events.names).to eq(%w[service_order_opened quote_generated stock_reserved])
  end
end
