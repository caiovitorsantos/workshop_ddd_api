require "rails_helper"

RSpec.describe Domain::Inventory::Part do
  def build(**overrides)
    described_class.new(
      **{ sku: "fil-ol01", description: "Filtro de óleo",
          unit_price: Domain::Shared::Money.from_amount(45),
          quantity_on_hand: 10, minimum_stock: 4 }.merge(overrides)
    )
  end

  it "normalises the SKU, so 'fil-ol01' and 'FIL-OL01' are the same part" do
    expect(build.sku).to eq("FIL-OL01")
  end

  describe "#deduct!" do
    it "reduces the balance on hand" do
      expect(build.deduct!(3).quantity_on_hand).to eq(7)
    end

    it "refuses to go negative — the invariant this context exists to protect" do
      expect { build(quantity_on_hand: 2).deduct!(3) }
        .to raise_error(Domain::Shared::Errors::BusinessRuleViolation, /insufficient stock/)
    end

    it "allows draining the shelf to exactly zero" do
      expect(build(quantity_on_hand: 3).deduct!(3).quantity_on_hand).to eq(0)
    end

    it "rejects a non-positive movement" do
      expect { build.deduct!(0) }
        .to raise_error(Domain::Shared::Errors::InvalidValue, /must be positive/)
    end
  end

  describe "#restock!" do
    it "increases the balance on hand" do
      expect(build.restock!(5).quantity_on_hand).to eq(15)
    end

    it "rejects a non-positive movement" do
      expect { build.restock!(-1) }
        .to raise_error(Domain::Shared::Errors::InvalidValue, /must be positive/)
    end
  end

  describe "#below_minimum?" do
    it "flags a part that fell under its reorder point" do
      expect(build(quantity_on_hand: 3, minimum_stock: 4)).to be_below_minimum
    end

    it "does not flag a part sitting exactly on its reorder point" do
      expect(build(quantity_on_hand: 4, minimum_stock: 4)).not_to be_below_minimum
    end
  end

  it "requires a SKU and a description" do
    expect { build(sku: "") }
      .to raise_error(Domain::Shared::Errors::InvalidValue, /SKU is required/)
    expect { build(description: " ") }
      .to raise_error(Domain::Shared::Errors::InvalidValue, /description is required/)
  end
end
