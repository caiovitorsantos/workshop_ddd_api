require "rails_helper"

# The workshop ends the order — wrong vehicle, duplicate entry, customer gave
# up. Like a rejection, it gives back any parts the order was holding; unlike a
# rejection, it can happen before a quote ever existed. Runs against the real
# repositories: status change and stock release are one transaction.
RSpec.describe Application::Workshop::CancelServiceOrder do
  def cancel(order, reason: nil)
    described_class.call(orders: orders, parts: parts, id: order.id, reason: reason)
  end

  def draft_order
    vehicle = create_vehicle
    Application::Workshop::OpenServiceOrder.call(
      orders: orders, vehicles: vehicles, customers: customers, vehicle_id: vehicle.id
    ).value
  end

  it "cancels an order that never got as far as a quote" do
    order = draft_order

    result = cancel(order, reason: "veículo errado")

    expect(result).to be_success
    expect(orders.find(order.id).status).to be_cancelled
  end

  it "releases parts reserved before the order was cancelled" do
    part  = create_part(on_hand: 10)
    order = draft_order
    Application::Workshop::AddPartToOrder.call(
      orders: orders, parts: parts, id: order.id, part_id: part.id, quantity: 4
    )

    expect(parts.find(part.id).quantity_reserved).to eq(4)

    cancel(orders.find(order.id))

    expect(parts.find(part.id).quantity_reserved).to eq(0)
    expect(parts.find(part.id).quantity_on_hand).to eq(10)
  end

  it "is a no-op on inventory when the order has no parts" do
    order = draft_order

    expect { cancel(order) }.not_to raise_error
    expect(orders.find(order.id).status).to be_cancelled
  end

  it "reports a missing order" do
    result = described_class.call(orders: orders, parts: parts, id: 999_999)

    expect(result).to be_failure
    expect(result.code).to eq(:not_found)
  end

  it "refuses to cancel an order already in progress" do
    order = order_awaiting_approval
    Application::Workshop::ApproveQuote.call(orders: orders, parts: parts, id: order.id)

    result = cancel(orders.find(order.id))

    expect(result).to be_failure
    expect(result.code).to eq(:invalid_transition)
  end
end
