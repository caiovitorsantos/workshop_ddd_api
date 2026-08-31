require "rails_helper"

# Application layer spec. It uses a fake repository instead of the database:
# the use case's job is orchestration, and that is what we assert here — the
# ActiveRecord adapter is covered by the request specs.
RSpec.describe Application::Registry::RegisterCustomer do
  # An in-memory implementation of the port. That this is only a few lines long
  # is the practical payoff of depending on an interface instead of ActiveRecord.
  let(:repository) do
    Class.new(Domain::Registry::CustomerRepository) do
      def initialize = @saved = []
      attr_reader :saved

      def save(customer) = tap { @saved << customer }.saved.last
      def find_by_tax_id(tax_id) = @saved.find { |c| c.tax_id == tax_id }
    end.new
  end

  it "registers a customer with a valid tax id" do
    result = described_class.call(
      repository: repository, tax_id: "529.982.247-25", name: "Maria Souza"
    )

    expect(result).to be_success
    expect(result.value.name).to eq("Maria Souza")
    expect(repository.saved.size).to eq(1)
  end

  it "returns a failure instead of raising when the tax id is invalid" do
    result = described_class.call(
      repository: repository, tax_id: "111.111.111-11", name: "Fraude"
    )

    expect(result).to be_failure
    expect(result.code).to eq(:invalid_value)
    expect(result.error).to match(/invalid CPF/)
    expect(repository.saved).to be_empty
  end

  it "refuses a duplicate tax id" do
    described_class.call(repository: repository, tax_id: "52998224725", name: "Maria")

    result = described_class.call(
      repository: repository, tax_id: "529.982.247-25", name: "Maria de novo"
    )

    expect(result).to be_failure
    expect(result.code).to eq(:already_exists)
    expect(repository.saved.size).to eq(1)
  end

  it "rejects a customer without a name" do
    result = described_class.call(repository: repository, tax_id: "52998224725", name: "")

    expect(result).to be_failure
    expect(result.error).to match(/name is required/)
  end
end
