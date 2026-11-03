require "rails_helper"

RSpec.describe ServiceOrderMailer do
  let(:customer) do
    Domain::Registry::Customer.new(
      id: 1, tax_id: Domain::Registry::TaxId.parse("52998224725"), name: "Maria Silva", email: "maria@exemplo.com"
    )
  end
  let(:order) { order_awaiting_approval }

  def mail_for(event) = described_class.status_changed(event: event, order: order, customer: customer)

  it "has a message for every notified event" do
    expect(described_class::MESSAGES.keys).to match_array(Infrastructure::Events::ActiveJobPublisher::NOTIFIED)
  end

  it "tells the customer what happened, the current status and where to follow it" do
    mail = mail_for("diagnosis_started")

    expect(mail.to).to eq([ "maria@exemplo.com" ])
    expect(mail.subject).to eq("Ordem de serviço #{order.number}: Aguardando aprovação")
    expect(mail.body.to_s).to include(
      "Olá, Maria Silva.", "Começamos o diagnóstico", "/api/v1/tracking/#{order.number}"
    )
  end

  it "shows the quote total only in the e-mail that asks for a decision" do
    expect(mail_for("quote_sent_to_customer").body.to_s).to include("Valor do orçamento: R$ 210.00")
    expect(mail_for("diagnosis_started").body.to_s).not_to include("R$")
  end

  it "leaves the plate and the diagnosis out of the inbox" do
    plate = vehicles.find(order.vehicle_id).plate

    body = mail_for("quote_sent_to_customer").body.to_s

    expect(body).not_to include(plate.code, plate.formatted, order.diagnosis)
  end
end
