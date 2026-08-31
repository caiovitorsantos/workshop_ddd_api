require "rails_helper"

# The most important integration spec in the suite.
#
# It runs against the real repositories and a real PostgreSQL on purpose: what
# is under test is a *transaction spanning two bounded contexts*, and a fake
# repository cannot prove that a rollback undid both halves.
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

    it "stamps the moment work was authorised" do
      order = order_awaiting_approval

      approved = approve(order).value

      expect(approved.approved_at).to be_present
      expect(approved.started_at).to eq(approved.approved_at)
    end
  end

  describe "when stock is short" do
    # The whole reason this use case exists. An approved order whose parts do
    # not exist is worse than a refused approval: the workshop has promised work
    # it cannot do.
    it "refuses the approval" do
      part  = create_part(on_hand: 1)
      order = order_awaiting_approval(part: part, part_quantity: 1)
      parts.save(parts.find(part.id).deduct!(1)) # someone else took the last one

      result = approve(order)

      expect(result).to be_failure
      expect(result.error).to match(/insufficient stock/)
    end

    it "leaves the order untouched — the status change is rolled back too" do
      part  = create_part(on_hand: 1)
      order = order_awaiting_approval(part: part, part_quantity: 1)
      parts.save(parts.find(part.id).deduct!(1))

      approve(order)

      expect(orders.find(order.id).status).to be_awaiting_approval
      expect(orders.find(order.id).approved_at).to be_nil
    end

    it "leaves every part untouched, including ones already deducted in the same call" do
      plentiful = create_part(sku: "OL-5W30", on_hand: 50)
      scarce    = create_part(sku: "FIL-OL01", on_hand: 1)
      vehicle   = create_vehicle

      order = Application::Workshop::OpenServiceOrder.call(
        orders: orders, vehicles: vehicles, customers: customers, vehicle_id: vehicle.id
      ).value
      Application::Workshop::AddPartToOrder.call(
        orders: orders, parts: parts, id: order.id, part_id: plentiful.id, quantity: 4
      )
      Application::Workshop::AddPartToOrder.call(
        orders: orders, parts: parts, id: order.id, part_id: scarce.id, quantity: 1
      )
      Application::Workshop::StartDiagnosis.call(repository: orders, id: order.id)
      Application::Workshop::SendQuote.call(repository: orders, id: order.id, diagnosis: "revisão")

      parts.save(parts.find(scarce.id).deduct!(1)) # the scarce one runs out

      approve(order)

      # The plentiful part is locked and deducted before the scarce one is even
      # looked at. Without a single transaction, its 4 units would be gone.
      expect(parts.find(plentiful.id).quantity_on_hand).to eq(50)
      expect(parts.find(scarce.id).quantity_on_hand).to eq(0)
    end
  end

  describe "the same part quoted on more than one line" do
    it "deducts the summed quantity, not each line against the full balance" do
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
    end

    it "refuses when the lines together exceed the balance, though each fits alone" do
      part    = create_part(on_hand: 3)
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

      expect(approve(order)).to be_failure
      expect(parts.find(part.id).quantity_on_hand).to eq(3)
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
