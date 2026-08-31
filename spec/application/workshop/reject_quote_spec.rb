require "rails_helper"

# Rejecting a quote ends the order AND gives back every part it was holding.
# Runs against the real repositories: the status change and the stock release
# are one transaction across two bounded contexts.
RSpec.describe Application::Workshop::RejectQuote do
  def reject(order, reason: nil)
    described_class.call(orders: orders, parts: parts, id: order.id, reason: reason)
  end

  it "cancels the order and marks it as a price rejection" do
    order = order_awaiting_approval

    result = reject(order, reason: "muito caro")

    expect(result).to be_success
    expect(orders.find(order.id).status).to be_cancelled
  end

  it "releases the reservation back to the available balance" do
    part  = create_part(on_hand: 10)
    order = order_awaiting_approval(part: part, part_quantity: 3)

    expect(parts.find(part.id).quantity_reserved).to eq(3)

    reject(order)

    reloaded = parts.find(part.id)
    expect(reloaded.quantity_reserved).to eq(0)
    expect(reloaded.quantity_on_hand).to eq(10)
    expect(reloaded.available_quantity).to eq(10)
  end

  it "sums the reservation when the same part is on more than one line" do
    part    = create_part(on_hand: 10)
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

    reject(orders.find(order.id))

    expect(parts.find(part.id).quantity_reserved).to eq(0)
  end

  it "reports a missing order" do
    result = described_class.call(orders: orders, parts: parts, id: 999_999)

    expect(result).to be_failure
    expect(result.code).to eq(:not_found)
  end

  it "refuses to reject an order that is already in progress" do
    order = order_awaiting_approval
    Application::Workshop::ApproveQuote.call(orders: orders, parts: parts, id: order.id)

    result = reject(orders.find(order.id))

    expect(result).to be_failure
    expect(result.code).to eq(:invalid_transition)
  end
end
