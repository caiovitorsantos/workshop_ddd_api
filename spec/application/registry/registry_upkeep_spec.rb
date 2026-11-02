require "rails_helper"

# Application specs with in-memory adapters (spec/support/in_memory_repository.rb):
# a use case's job is orchestration, and none of these needs a database to
# prove it. The ActiveRecord side is covered by the request specs.
RSpec.describe "Registry upkeep use cases" do
  let(:customers) { in_memory(Domain::Registry::CustomerRepository) }
  let(:vehicles)  { in_memory(Domain::Registry::VehicleRepository) }
  let(:in_use)    { Domain::Shared::Errors::InUse }

  let(:customer) do
    customers.save(
      Domain::Registry::Customer.new(
        tax_id: Domain::Registry::TaxId.parse("529.982.247-25"), name: "Maria Souza",
        email: "maria@exemplo.com", phone: "11999990000"
      )
    )
  end

  let(:vehicle) do
    vehicles.save(
      Domain::Registry::Vehicle.new(
        plate: Domain::Registry::LicensePlate.parse("ABC1D23"),
        make: "Volkswagen", model: "Gol", year: 2019, customer_id: 1
      )
    )
  end

  describe Application::Registry::UpdateCustomerContact do
    subject(:update) { described_class.new(customers: customers) }

    it "changes only what was sent" do
      result = update.call(id: customer.id, phone: "(11) 98888-7777")

      expect(result).to be_success
      expect(result.value.phone).to eq("11988887777")
      expect(result.value.name).to eq("Maria Souza")
      expect(customers.find(customer.id).phone).to eq("11988887777")
    end

    it "reports a missing customer" do
      expect(update.call(id: 999, name: "Outra").code).to eq(:not_found)
    end

    it "refuses an invalid change and leaves the stored customer alone" do
      result = update.call(id: customer.id, name: "")

      expect(result.code).to eq(:invalid_value)
      expect(customers.find(customer.id).name).to eq("Maria Souza")
    end
  end

  describe Application::Registry::RemoveCustomer do
    it "removes the customer" do
      described_class.new(customers: customers).call(id: customer.id)

      expect(customers.find(customer.id)).to be_nil
    end

    it "reports a customer still referenced as in use, without raising" do
      blocked = Class.new(Domain::Registry::CustomerRepository) do
        def delete(_id) = raise(Domain::Shared::Errors::InUse, "customer still has vehicles attached")
      end.new

      result = described_class.new(customers: blocked).call(id: 1)

      expect(result.code).to eq(:in_use)
      expect(result.error).to match(/vehicles attached/)
    end
  end

  describe Application::Registry::CorrectVehicleDetails do
    subject(:correct) { described_class.new(vehicles: vehicles) }

    it "corrects the details sent and keeps the plate" do
      result = correct.call(id: vehicle.id, model: "Gol G7")

      expect(result.value.model).to eq("Gol G7")
      expect(result.value.make).to eq("Volkswagen")
      expect(result.value.plate.formatted).to eq("ABC1D23")
    end

    it "reports a missing vehicle" do
      expect(correct.call(id: 999, year: 2020).code).to eq(:not_found)
    end
  end

  describe Application::Registry::RemoveVehicle do
    it "removes the vehicle" do
      described_class.new(vehicles: vehicles).call(id: vehicle.id)

      expect(vehicles.find(vehicle.id)).to be_nil
    end
  end
end
