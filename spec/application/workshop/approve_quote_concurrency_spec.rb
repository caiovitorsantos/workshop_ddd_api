require "rails_helper"

# Proves that `find_for_update` actually serialises competing approvals.
#
# This is the one spec in the suite that cannot use transactional fixtures: two
# threads need two real connections seeing each other's committed writes, which
# is impossible inside a single wrapping transaction. It cleans up after itself
# instead.
#
# Without the row lock, both threads read "1 on hand", both pass
# `Part#available?(1)`, and both deduct — leaving -1 on the shelf, or a CHECK
# violation if the database catches it. Either way the workshop has promised a
# part twice.
RSpec.describe Application::Workshop::ApproveQuote, "under concurrency" do
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

  it "lets exactly one of two simultaneous approvals take the last unit" do
    part = create_part(on_hand: 1, minimum: 0)

    # Two independent orders, each quoting the single remaining unit.
    first  = order_awaiting_approval(part: part, part_quantity: 1)
    second = order_awaiting_approval(part: part, part_quantity: 1)

    results = [ first, second ].map do |order|
      Thread.new do
        # Each thread checks out its own connection from the pool; without this
        # they would share one and never actually contend.
        ActiveRecord::Base.connection_pool.with_connection do
          described_class.call(
            orders: Infrastructure::Persistence::Repositories::ServiceOrdersInActiveRecord.new,
            parts: Infrastructure::Persistence::Repositories::PartsInActiveRecord.new,
            id: order.id
          )
        end
      end
    end.map(&:value)

    expect(results.count(&:success?)).to eq(1)
    expect(results.count(&:failure?)).to eq(1)
    expect(results.find(&:failure?).error).to match(/insufficient stock/)

    # The invariant that matters: the shelf never went negative.
    expect(parts.find(part.id).quantity_on_hand).to eq(0)
  end

  it "gives two simultaneous opens distinct order numbers" do
    vehicles_to_use = [ create_vehicle(plate: "AAA1A11"), create_vehicle(plate: "BBB2B22") ]

    numbers = vehicles_to_use.map do |vehicle|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Application::Workshop::OpenServiceOrder.call(
            orders: Infrastructure::Persistence::Repositories::ServiceOrdersInActiveRecord.new,
            vehicles: Infrastructure::Persistence::Repositories::VehiclesInActiveRecord.new,
            customers: Infrastructure::Persistence::Repositories::CustomersInActiveRecord.new,
            vehicle_id: vehicle.id
          ).value.number
        end
      end
    end.map(&:value)

    expect(numbers.uniq.size).to eq(2)
  end
end
