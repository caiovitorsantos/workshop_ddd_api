require "rails_helper"

# Domain events of the Inventory context — the stickies from the parts board
# (PLANO_TECH_CHALLENGE.md §2.7), asserted one by one.
RSpec.describe Domain::Inventory::Part, "domain events" do
  let(:clock) { class_double(Time, current: Time.zone.parse("2026-03-01 08:00:00")) }

  def build(**overrides)
    described_class.new(
      **{ id: 7, sku: "FIL-OL01", description: "Filtro de óleo",
          unit_price: Domain::Shared::Money.from_amount(45),
          quantity_on_hand: 10, minimum_stock: 4, clock: clock }.merge(overrides)
    )
  end

  describe "#reserve!" do
    it "publishes StockReserved carrying the order that reserved the part" do
      events = build.reserve!(3, service_order_id: 99).drain_events

      expect(events.map(&:name)).to eq([ "stock_reserved" ])
      expect(events.first.payload).to eq(quantity: 3, service_order_id: 99)
      expect(events.first.aggregate_id).to eq(7)
      expect(events.first.occurred_at).to eq(clock.current)
    end

    it "publishes InsufficientStockDetected and nothing else when it refuses" do
      part = build(quantity_on_hand: 2)

      expect { part.reserve!(3) }.to raise_error(Domain::Shared::Errors::BusinessRuleViolation)

      events = part.drain_events
      expect(events.map(&:name)).to eq([ "insufficient_stock_detected" ])
      expect(events.first.payload).to eq(sku: "FIL-OL01", requested: 3, available: 2)
    end
  end

  describe "#consume_reserved!" do
    it "publishes StockDeducted carrying the order that consumed the part" do
      events = build(quantity_reserved: 5).consume_reserved!(3, service_order_id: 99).drain_events

      expect(events.map(&:name)).to eq([ "stock_deducted" ])
      expect(events.first.payload).to eq(quantity: 3, service_order_id: 99)
      expect(events.first.aggregate_id).to eq(7)
      expect(events.first.occurred_at).to eq(clock.current)
    end

    it "publishes nothing when it refuses the movement" do
      part = build(quantity_reserved: 2)

      expect { part.consume_reserved!(3) }.to raise_error(Domain::Shared::Errors::BusinessRuleViolation)
      expect(part.drain_events).to be_empty
    end
  end

  describe "#release!" do
    it "publishes StockReleased carrying the order it came back from" do
      events = build(quantity_reserved: 4).release!(3, service_order_id: 99).drain_events

      expect(events.map(&:name)).to eq([ "stock_released" ])
      expect(events.first.payload).to eq(quantity: 3, service_order_id: 99)
    end

    it "publishes nothing when it refuses the movement" do
      part = build(quantity_reserved: 2)

      expect { part.release!(3) }.to raise_error(Domain::Shared::Errors::BusinessRuleViolation)
      expect(part.drain_events).to be_empty
    end
  end

  describe "#restock!" do
    it "publishes StockReplenished" do
      events = build.restock!(5).drain_events

      expect(events.map(&:name)).to eq([ "stock_replenished" ])
      expect(events.first.payload[:quantity]).to eq(5)
    end

    it "carries the order id when parts come back from a cancelled order" do
      events = build.restock!(2, service_order_id: 99).drain_events

      expect(events.first.payload[:service_order_id]).to eq(99)
    end
  end

  describe "PartBelowMinimum and ReplenishmentRequested" do
    it "both fire, in that order, when a deduction crosses the reorder point" do
      # 10 on hand, all reserved, minimum 4: consuming 7 lands on 3, below the line.
      events = build(quantity_on_hand: 10, quantity_reserved: 10, minimum_stock: 4)
        .consume_reserved!(7).drain_events

      expect(events.map(&:name))
        .to eq([ "stock_deducted", "part_below_minimum", "replenishment_requested" ])
      expect(events[1].payload).to eq(quantity_on_hand: 3, minimum_stock: 4)
      expect(events[2].payload).to eq(quantity_on_hand: 3, minimum_stock: 4)
    end

    it "do not fire while the balance stays at or above the point" do
      events = build(quantity_on_hand: 10, quantity_reserved: 10, minimum_stock: 4)
        .consume_reserved!(6).drain_events

      expect(events.map(&:name)).to eq([ "stock_deducted" ])
    end

    it "do not fire again on a further deduction while already below" do
      part = build(quantity_on_hand: 3, quantity_reserved: 3, minimum_stock: 4)

      expect(part.consume_reserved!(1).drain_events.map(&:name)).to eq([ "stock_deducted" ])
    end

    it "do not fire on a reservation, even one that exhausts the available balance" do
      events = build(quantity_on_hand: 10, minimum_stock: 4).reserve!(10).drain_events

      expect(events.map(&:name)).to eq([ "stock_reserved" ])
    end
  end

  describe "#drain_events" do
    it "hands the events over and forgets them" do
      part = build(quantity_reserved: 2)
      part.consume_reserved!(1)

      expect(part.drain_events.size).to eq(1)
      expect(part.drain_events).to be_empty
    end
  end
end
