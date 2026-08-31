require "rails_helper"

# Adding a part to an order now *reserves* stock: the physical balance stays put
# but the amount is held so another order cannot quote it. Runs against the real
# repositories and PostgreSQL — the reservation and the order line land in one
# transaction, and a rollback has to undo both.
RSpec.describe Application::Workshop::AddPartToOrder do
  def draft_order
    vehicle = create_vehicle
    must_succeed(
      Application::Workshop::OpenServiceOrder.call(
        orders: orders, vehicles: vehicles, customers: customers, vehicle_id: vehicle.id
      )
    )
  end

  def add(order, part, quantity)
    described_class.call(
      orders: orders, parts: parts, id: order.id, part_id: part.id, quantity: quantity
    )
  end

  describe "the happy path" do
    it "holds the stock and puts the line on the order" do
      part  = create_part(on_hand: 10)
      order = draft_order

      result = add(order, part, 3)

      expect(result).to be_success
      expect(parts.find(part.id).quantity_reserved).to eq(3)
      expect(parts.find(part.id).quantity_on_hand).to eq(10)
      expect(orders.find(order.id).part_items.map(&:part_id)).to eq([ part.id ])
    end

    it "reserves against what is available, so a second line sees the first one's hold" do
      part  = create_part(on_hand: 5)
      order = draft_order

      expect(add(order, part, 3)).to be_success
      expect(add(order, part, 2)).to be_success
      expect(parts.find(part.id).quantity_reserved).to eq(5)
    end
  end

  describe "when the stock is not available" do
    it "refuses the addition and reports why" do
      part  = create_part(on_hand: 2)
      order = draft_order

      result = add(order, part, 3)

      expect(result).to be_failure
      expect(result.code).to eq(:business_rule_violation)
      expect(result.error).to match(/insufficient stock/)
    end

    it "leaves both the order and the part untouched" do
      part  = create_part(on_hand: 2)
      order = draft_order

      add(order, part, 3)

      expect(orders.find(order.id).part_items).to be_empty
      expect(parts.find(part.id).quantity_reserved).to eq(0)
    end

    it "counts stock already reserved by the same order" do
      part  = create_part(on_hand: 4)
      order = draft_order

      expect(add(order, part, 3)).to be_success
      expect(add(order, part, 2)).to be_failure
      expect(parts.find(part.id).quantity_reserved).to eq(3)
    end
  end

  describe "guards" do
    it "refuses to add a part to an order that is no longer a draft" do
      fresh_part = create_part(on_hand: 10)
      order      = order_awaiting_approval

      result = add(order, fresh_part, 1)

      expect(result).to be_failure
      expect(result.code).to eq(:invalid_transition)
      expect(parts.find(fresh_part.id).quantity_reserved).to eq(0)
    end

    it "reports a missing order" do
      part = create_part

      result = described_class.call(
        orders: orders, parts: parts, id: 999_999, part_id: part.id, quantity: 1
      )

      expect(result).to be_failure
      expect(result.code).to eq(:not_found)
    end

    it "reports a missing part" do
      order = draft_order

      result = described_class.call(
        orders: orders, parts: parts, id: order.id, part_id: 999_999, quantity: 1
      )

      expect(result).to be_failure
      expect(result.code).to eq(:not_found)
    end
  end
end
