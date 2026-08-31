require "rails_helper"

# The most important integration spec in the suite.
#
# It runs against the real repositories and a real PostgreSQL on purpose: what
# is under test is a *transaction spanning two bounded contexts*, and a fake
# repository cannot prove that a rollback undid both halves.
#
# In the two-phase stock flow the parts are already *reserved* by the time an
# order reaches approval (see AddPartToOrder), so approval cannot fail for want
# of stock — that check moved to the moment the part was added. What approval
# does is turn each reservation into a real deduction.
RSpec.describe Application::Workshop::ApproveQuote do
  def approve(order)
    described_class.call(orders: orders, parts: parts, id: order.id)
  end

  describe "the happy path" do
    it "approves the order and takes the quoted parts off the shelf" do
      part  = create_part(on_hand: 10)
      order = order_awaiting_approval(part: part, part_quantity: 3)

      result = approve(order)

      expect(result).to be_success
      expect(orders.find(order.id).status).to be_in_progress
      expect(parts.find(part.id).quantity_on_hand).to eq(7)
    end

    it "clears the reservation as it deducts — nothing stays held" do
      part  = create_part(on_hand: 10)
      order = order_awaiting_approval(part: part, part_quantity: 3)

      approve(order)

      reloaded = parts.find(part.id)
      expect(reloaded.quantity_reserved).to eq(0)
      expect(reloaded.available_quantity).to eq(7)
    end

    it "stamps the moment work was authorised" do
      order = order_awaiting_approval

      approved = approve(order).value

      expect(approved.approved_at).to be_present
      expect(approved.started_at).to eq(approved.approved_at)
    end
  end

  describe "the same part quoted on more than one line" do
    it "consumes the summed quantity, not each line against the full balance" do
      part    = create_part(on_hand: 5)
      vehicle = create_vehicle

      order = Application::Workshop::OpenServiceOrder.call(
        orders: orders, vehicles: vehicles, customers: customers, vehicle_id: vehicle.id
      ).value
      2.times do
        Application::Workshop::AddPartToOrder.call(
          orders: orders, parts: parts, id: order.id, part_id: part.id, quantity: 2
        )
      end
      Application::Workshop::StartDiagnosis.call(repository: orders, id: order.id)
      Application::Workshop::SendQuote.call(repository: orders, id: order.id, diagnosis: "revisão")

      expect(approve(order)).to be_success
      expect(parts.find(part.id).quantity_on_hand).to eq(1)
      expect(parts.find(part.id).quantity_reserved).to eq(0)
    end
  end

  describe "guards" do
    it "reports a missing order rather than exploding" do
      result = described_class.call(orders: orders, parts: parts, id: 999_999)

      expect(result).to be_failure
      expect(result.code).to eq(:not_found)
    end

    it "refuses to approve an order that is not awaiting approval" do
      order = order_awaiting_approval
      approve(order)

      second = approve(orders.find(order.id))

      expect(second).to be_failure
      expect(second.code).to eq(:invalid_transition)
    end

    it "does not double-deduct when approval is attempted twice" do
      part  = create_part(on_hand: 10)
      order = order_awaiting_approval(part: part, part_quantity: 3)

      approve(order)
      approve(orders.find(order.id))

      expect(parts.find(part.id).quantity_on_hand).to eq(7)
    end
  end

  describe "an order with no parts" do
    it "approves without touching inventory" do
      service = create_service
      vehicle = create_vehicle

      order = Application::Workshop::OpenServiceOrder.call(
        orders: orders, vehicles: vehicles, customers: customers, vehicle_id: vehicle.id
      ).value
      Application::Workshop::AddServiceToOrder.call(
        orders: orders, services: services, id: order.id, service_id: service.id
      )
      Application::Workshop::StartDiagnosis.call(repository: orders, id: order.id)
      Application::Workshop::SendQuote.call(repository: orders, id: order.id, diagnosis: "só mão de obra")

      expect(approve(orders.find(order.id))).to be_success
    end
  end
end
