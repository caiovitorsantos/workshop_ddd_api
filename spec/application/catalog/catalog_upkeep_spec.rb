require "rails_helper"

RSpec.describe "Catalog upkeep use cases" do
  let(:services) { in_memory(Domain::Catalog::ServiceRepository) }

  let(:service) do
    services.save(
      Domain::Catalog::Service.new(
        name: "Troca de óleo", price: Domain::Shared::Money.from_amount(120),
        estimated_minutes: 30
      )
    )
  end

  describe Application::Catalog::ReviseService do
    subject(:revise) { described_class.new(services: services) }

    it "turns a plain price into Money at the edge of the domain" do
      result = revise.call(id: service.id, price: "150.50")

      expect(result).to be_success
      expect(result.value.price).to eq(Domain::Shared::Money.from_amount("150.50"))
      expect(result.value.name).to eq("Troca de óleo")
    end

    it "leaves the price alone when it was not sent" do
      result = revise.call(id: service.id, name: "Troca de óleo sintético")

      expect(result.value.price).to eq(Domain::Shared::Money.from_amount(120))
    end

    it "reports a missing service" do
      expect(revise.call(id: 999, name: "Outro").code).to eq(:not_found)
    end

    it "refuses a revision that breaks the service's rules" do
      expect(revise.call(id: service.id, name: "").code).to eq(:invalid_value)
    end
  end

  describe Application::Catalog::RetireService do
    subject(:retire) { described_class.new(services: services) }

    it "takes the service out of what is offered, keeping it on the books" do
      result = retire.call(id: service.id)

      expect(result.value).not_to be_active
      expect(services.find(service.id)).not_to be_active
    end

    it "reports a missing service" do
      expect(retire.call(id: 999).code).to eq(:not_found)
    end
  end

  describe Application::Catalog::RemoveService do
    it "removes a service that was never used" do
      described_class.new(services: services).call(id: service.id)

      expect(services.find(service.id)).to be_nil
    end
  end
end
