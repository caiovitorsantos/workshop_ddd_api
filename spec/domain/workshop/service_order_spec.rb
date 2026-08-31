require "rails_helper"

# The core subdomain's spec. Every rule that makes the workshop's process work
# is asserted here, with no database in the way.
RSpec.describe Domain::Workshop::ServiceOrder do
  # Frozen clock, so duration assertions are exact instead of flaky.
  let(:clock) { class_double(Time, current: Time.zone.parse("2026-03-01 08:00:00")) }

  def open_order
    described_class.open(number: "OS-0001", customer_id: 1, vehicle_id: 2, clock: clock)
  end

  def money(amount) = Domain::Shared::Money.from_amount(amount)

  # Walks the order up to the point where a quote has been sent.
  def order_awaiting_approval
    open_order
      .add_service(service_id: 10, description: "Troca de óleo", unit_price: money(120))
      .add_part(part_id: 20, description: "Filtro de óleo", unit_price: money(45), quantity: 2)
      .start_diagnosis!
      .send_quote!(diagnosis: "Óleo vencido e filtro saturado")
  end

  describe "opening" do
    it "starts in 'received'" do
      expect(open_order.status).to be_received
    end

    it "records the ServiceOrderOpened event" do
      expect(open_order.drain_events.map(&:name)).to include("service_order_opened")
    end

    it "refuses to open without a vehicle" do
      expect { described_class.open(number: "OS-1", customer_id: 1, vehicle_id: nil) }
        .to raise_error(Domain::Shared::Errors::InvalidValue, /vehicle is required/)
    end
  end

  describe "quote generation" do
    it "adds up labour and parts automatically as items come in" do
      order = open_order
        .add_service(service_id: 10, description: "Troca de óleo", unit_price: money(120))
        .add_part(part_id: 20, description: "Filtro", unit_price: money(45), quantity: 2)

      expect(order.quote.labour_total).to eq(money(120))
      expect(order.quote.parts_total).to eq(money(90))
      expect(order.quote.total).to eq(money(210))
    end

    it "refuses to send a quote with no items" do
      order = open_order.start_diagnosis!

      expect { order.send_quote!(diagnosis: "nada a fazer") }
        .to raise_error(Domain::Shared::Errors::BusinessRuleViolation, /no services or parts/)
    end

    it "refuses to send a quote with no diagnosis" do
      order = open_order
        .add_service(service_id: 10, description: "Troca de óleo", unit_price: money(120))
        .start_diagnosis!

      expect { order.send_quote!(diagnosis: "  ") }
        .to raise_error(Domain::Shared::Errors::BusinessRuleViolation, /describe the diagnosis/)
    end
  end

  describe "life cycle" do
    it "moves the status automatically as business commands run" do
      order = order_awaiting_approval
      expect(order.status).to be_awaiting_approval

      order.approve_quote!
      expect(order.status).to be_in_progress

      order.complete!
      expect(order.status).to be_completed

      order.deliver!
      expect(order.status).to be_delivered
    end

    it "cancels when the customer rejects the quote" do
      order = order_awaiting_approval.reject_quote!(reason: "muito caro")

      expect(order.status).to be_cancelled
      expect(order.drain_events.map(&:name)).to include("quote_rejected")
    end

    # A rejected quote is a lost sale; a cancelled order is not. Both end in
    # `cancelled`, so only the event tells them apart — and a report on sales
    # lost to price depends on that distinction.
    it "distinguishes a workshop cancellation from a customer rejection" do
      cancelled = open_order.cancel!(reason: "veículo errado")

      expect(cancelled.status).to be_cancelled

      names = cancelled.drain_events.map(&:name)
      expect(names).to include("service_order_cancelled")
      expect(names).not_to include("quote_rejected")
    end

    it "reports the reason on both endings" do
      rejected = order_awaiting_approval.reject_quote!(reason: "muito caro")
      cancelled = open_order.cancel!(reason: "duplicada")

      expect(rejected.drain_events.last.payload[:reason]).to eq("muito caro")
      expect(cancelled.drain_events.last.payload[:reason]).to eq("duplicada")
    end

    it "refuses to skip states" do
      order = open_order

      expect { order.deliver! }
        .to raise_error(Domain::Shared::Errors::InvalidTransition, /Recebida.*Entregue/)
    end

    it "refuses to reopen a delivered order" do
      order = order_awaiting_approval.approve_quote!.complete!.deliver!

      expect { order.start_diagnosis! }
        .to raise_error(Domain::Shared::Errors::InvalidTransition)
    end
  end

  describe "aggregate boundary" do
    it "refuses to add items once the quote is with the customer" do
      order = order_awaiting_approval

      expect { order.add_service(service_id: 11, description: "Alinhamento", unit_price: money(80)) }
        .to raise_error(Domain::Shared::Errors::InvalidTransition, /cannot add services/)
    end

    it "hands out frozen item collections, so nobody mutates them from outside" do
      order = open_order.add_service(service_id: 10, description: "Troca", unit_price: money(120))

      expect(order.service_items).to be_frozen
      expect { order.service_items << :sneaky }.to raise_error(FrozenError)
    end
  end

  describe "execution time" do
    it "measures how long the order took from opening to delivery" do
      opened_at    = Time.zone.parse("2026-03-01 08:00:00")
      delivered_at = Time.zone.parse("2026-03-01 12:00:00")
      moving_clock = class_double(Time)
      allow(moving_clock).to receive(:current).and_return(opened_at)

      order = described_class
        .open(number: "OS-0002", customer_id: 1, vehicle_id: 2, clock: moving_clock)
        .add_service(service_id: 10, description: "Revisão", unit_price: money(300))
        .start_diagnosis!
        .send_quote!(diagnosis: "revisão completa")
        .approve_quote!

      allow(moving_clock).to receive(:current).and_return(delivered_at)
      order.complete!.deliver!

      expect(order.total_duration).to eq(4.hours)
      expect(order.work_duration).to eq(4.hours)
    end
  end
end
