require "rails_helper"

# Rejecting a quote ends the order AND gives back every part it was holding.
# Runs against the real repositories: the status change and the stock release
# are one transaction across two bounded contexts.
RSpec.describe Application::Workshop::RejectQuote do
  subject(:use_case) do
    described_class.new(orders: orders, parts: parts, transaction: transaction, events: events)
  end

  def reject(order, reason: nil)
    use_case.call(id: order.id, reason: reason)
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

    order = open_order_for(vehicle).value
    2.times do
      container.add_part_to_order.call(
        id: order.id, part_id: part.id, quantity: 2
      )
    end
    container.start_diagnosis.call(id: order.id)
    container.send_quote.call(id: order.id, diagnosis: "revisão")

    reject(orders.find(order.id))

    expect(parts.find(part.id).quantity_reserved).to eq(0)
  end

  it "publishes the rejection and the stock it gave back" do
    order = order_awaiting_approval

    reject(order)

    expect(events.names).to eq(%w[quote_rejected stock_released])
  end

  it "reports a missing order" do
    result = use_case.call(id: 999_999)

    expect(result).to be_failure
    expect(result.code).to eq(:not_found)
  end

  it "refuses to reject an order that is already in progress" do
    order = order_awaiting_approval
    container.approve_quote.call(id: order.id)

    result = reject(orders.find(order.id))

    expect(result).to be_failure
    expect(result.code).to eq(:invalid_transition)
  end
end
