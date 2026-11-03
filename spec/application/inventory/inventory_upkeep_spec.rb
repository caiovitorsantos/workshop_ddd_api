require "rails_helper"

RSpec.describe "Inventory upkeep use cases" do
  let(:parts) { in_memory(Domain::Inventory::PartRepository) }

  let(:part) do
    parts.save(
      Domain::Inventory::Part.new(
        sku: "FIL-1", description: "Filtro de óleo",
        unit_price: Domain::Shared::Money.from_amount(45),
        quantity_on_hand: 10, quantity_reserved: 3, minimum_stock: 2
      )
    )
  end

  describe Application::Inventory::RevisePart do
    subject(:revise) { described_class.new(parts: parts) }

    it "turns a plain unit price into Money" do
      result = revise.call(id: part.id, unit_price: "52.90")

      expect(result.value.unit_price).to eq(Domain::Shared::Money.from_amount("52.90"))
    end

    it "never touches the stock levels" do
      result = revise.call(id: part.id, description: "Filtro de óleo premium", minimum_stock: 5)

      expect(result.value.quantity_on_hand).to eq(10)
      expect(result.value.quantity_reserved).to eq(3)
      expect(result.value.minimum_stock).to eq(5)
    end

    it "reports a missing part" do
      expect(revise.call(id: 999, description: "x").code).to eq(:not_found)
    end
  end

  describe Application::Inventory::RemovePart do
    it "removes a part that was never moved" do
      described_class.new(parts: parts).call(id: part.id)

      expect(parts.find(part.id)).to be_nil
    end
  end
end
