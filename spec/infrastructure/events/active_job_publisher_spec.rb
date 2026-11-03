require "rails_helper"

RSpec.describe Infrastructure::Events::ActiveJobPublisher do
  let(:output) { StringIO.new }
  let(:publisher) { described_class.new(logger: Logger.new(output)) }

  def event(type, aggregate_id: 42)
    type.new(aggregate_id: aggregate_id, occurred_at: Time.current, payload: {})
  end

  Workshop = Domain::Workshop::Events

  it "queues one e-mail per status change the customer sees, and still logs every event" do
    publisher.publish([
      event(Workshop::QuoteApproved), event(Workshop::WorkStarted),
      event(Workshop::QuoteGenerated), event(Domain::Inventory::Events::StockDeducted, aggregate_id: 7)
    ])

    expect(NotifyCustomerJob).to have_been_enqueued.exactly(:once).with("work_started", 42)
    expect(output.string).to include("domain_event=quote_approved", "domain_event=stock_deducted")
  end

  it "covers every customer-facing event on the board" do
    expect(described_class::NOTIFIED).to all(satisfy { |name| Workshop.const_defined?(name.camelize) })
  end

  describe "wired into the use cases" do
    let(:part) { create_part(on_hand: 1) }
    let(:input) { opening_of(create_vehicle).merge(parts: [ { part_id: part.id, quantity: 1 } ]) }

    it "queues the opening e-mail for the order just saved" do
      order = container.open_service_order.call(**input).value

      expect(NotifyCustomerJob).to have_been_enqueued.with("service_order_opened", order.id)
    end

    it "queues nothing for an operation that rolled back" do
      input[:parts] = [ { part_id: part.id, quantity: 2 } ] # more than on hand

      expect(container.open_service_order.call(**input)).to be_failure
      expect(NotifyCustomerJob).not_to have_been_enqueued
    end
  end
end
