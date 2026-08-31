require "rails_helper"

# Proves that `find_for_update` actually serialises competing stock movements.
#
# This is the one spec in the suite that cannot use transactional fixtures: two
# threads need two real connections seeing each other's committed writes, which
# is impossible inside a single wrapping transaction. It cleans up after itself
# instead.
#
# Two races matter in the two-phase stock flow:
#
#   - two orders reserving the last unit at the same time (AddPartToOrder);
#   - two approvals deducting the same part at the same time (ApproveQuote),
#     where a lost update would leave stock that was already promised.
#
# Without the row lock, both threads read the same balance and one write wins,
# silently dropping the other. Either way the workshop has promised a part it
# does not have.
RSpec.describe "stock movements under concurrency" do
  self.use_transactional_tests = false

  # Nothing rolls back here, so the spec is responsible for its own mess.
  # Children first, then parents — the foreign keys are real.
  after do
    [ Infrastructure::Persistence::Records::PartItem,
      Infrastructure::Persistence::Records::ServiceItem,
      Infrastructure::Persistence::Records::ServiceOrder,
      Infrastructure::Persistence::Records::StockMovement,
      Infrastructure::Persistence::Records::Vehicle,
      Infrastructure::Persistence::Records::Customer,
      Infrastructure::Persistence::Records::Part,
      Infrastructure::Persistence::Records::Service ].each(&:delete_all)
  end

  def in_own_connection
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection { yield }
    end
  end

  def draft_order
    vehicle = create_vehicle
    Application::Workshop::OpenServiceOrder.call(
      orders: orders, vehicles: vehicles, customers: customers, vehicle_id: vehicle.id
    ).value
  end

  it "lets exactly one of two simultaneous additions reserve the last unit" do
    part   = create_part(on_hand: 1, minimum: 0)
    first  = draft_order
    second = draft_order

    results = [ first, second ].map do |order|
      in_own_connection do
        Application::Workshop::AddPartToOrder.call(
          orders: Infrastructure::Persistence::Repositories::ServiceOrdersInActiveRecord.new,
          parts: Infrastructure::Persistence::Repositories::PartsInActiveRecord.new,
          id: order.id, part_id: part.id, quantity: 1
        )
      end
    end.map(&:value)

    expect(results.count(&:success?)).to eq(1)
    expect(results.count(&:failure?)).to eq(1)
    expect(results.find(&:failure?).error).to match(/insufficient stock/)

    reloaded = parts.find(part.id)
    expect(reloaded.quantity_reserved).to eq(1)
    expect(reloaded.available_quantity).to eq(0)
  end

  it "serialises two simultaneous approvals that deduct the same part" do
    part   = create_part(on_hand: 5, minimum: 0)
    first  = order_awaiting_approval(part: part, part_quantity: 3)
    second = order_awaiting_approval(part: part, part_quantity: 2)

    results = [ first, second ].map do |order|
      in_own_connection do
        Application::Workshop::ApproveQuote.call(
          orders: Infrastructure::Persistence::Repositories::ServiceOrdersInActiveRecord.new,
          parts: Infrastructure::Persistence::Repositories::PartsInActiveRecord.new,
          id: order.id
        )
      end
    end.map(&:value)

    expect(results.count(&:success?)).to eq(2)

    # The invariant that matters: every reserved unit was actually deducted,
    # nothing was lost to a stale read.
    reloaded = parts.find(part.id)
    expect(reloaded.quantity_on_hand).to eq(0)
    expect(reloaded.quantity_reserved).to eq(0)
  end

  it "gives two simultaneous opens distinct order numbers" do
    vehicles_to_use = [ create_vehicle(plate: "AAA1A11"), create_vehicle(plate: "BBB2B22") ]

    numbers = vehicles_to_use.map do |vehicle|
      in_own_connection do
        Application::Workshop::OpenServiceOrder.call(
          orders: Infrastructure::Persistence::Repositories::ServiceOrdersInActiveRecord.new,
          vehicles: Infrastructure::Persistence::Repositories::VehiclesInActiveRecord.new,
          customers: Infrastructure::Persistence::Repositories::CustomersInActiveRecord.new,
          vehicle_id: vehicle.id
        ).value.number
      end
    end.map(&:value)

    expect(numbers.uniq.size).to eq(2)
  end
end
