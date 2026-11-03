require "rails_helper"

RSpec.describe NotifyCustomerJob do
  def customer_with(email:)
    customers.save(
      Domain::Registry::Customer.new(
        tax_id: Domain::Registry::TaxId.parse(generate_cpf), name: "Maria Silva", email: email
      )
    )
  end

  it "e-mails the customer about the order as it stands now" do
    order = draft_order(vehicle: create_vehicle(customer: customer_with(email: "maria@exemplo.com")))

    described_class.perform_now("service_order_opened", order.id)

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ "maria@exemplo.com" ])
    expect(mail.subject).to eq("Ordem de serviço #{order.number}: Recebida")
  end

  it "does nothing, without failing, when the customer left no e-mail" do
    order = draft_order(vehicle: create_vehicle(customer: customer_with(email: nil)))

    expect { described_class.perform_now("service_order_opened", order.id) }.not_to raise_error
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "does nothing when the order is gone" do
    described_class.perform_now("service_order_opened", 999_999)

    expect(ActionMailer::Base.deliveries).to be_empty
  end
end
