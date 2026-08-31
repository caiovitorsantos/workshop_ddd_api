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

  describe "#available_quantity" do
    it "is the balance on hand minus what is reserved" do
      expect(build(quantity_on_hand: 10, quantity_reserved: 3).available_quantity).to eq(7)
    end

    it "equals the balance on hand when nothing is reserved" do
      expect(build(quantity_on_hand: 10).available_quantity).to eq(10)
    end
  end

  describe "#available?" do
    it "answers against the available balance, not the physical one" do
      part = build(quantity_on_hand: 10, quantity_reserved: 8)

      expect(part.available?(2)).to be(true)
      expect(part.available?(3)).to be(false)
    end
  end

  describe "#reserve!" do
    it "holds stock without touching the physical balance" do
      part = build(quantity_on_hand: 10).reserve!(3)

      expect(part.quantity_reserved).to eq(3)
      expect(part.quantity_on_hand).to eq(10)
      expect(part.available_quantity).to eq(7)
    end

    it "can reserve the whole available balance" do
      expect(build(quantity_on_hand: 10, quantity_reserved: 4).reserve!(6).quantity_reserved).to eq(10)
    end

    it "refuses to reserve more than is available" do
      expect { build(quantity_on_hand: 10, quantity_reserved: 8).reserve!(3) }
        .to raise_error(Domain::Shared::Errors::BusinessRuleViolation, /insufficient stock/)
    end

    it "rejects a non-positive reservation" do
      expect { build.reserve!(0) }
        .to raise_error(Domain::Shared::Errors::InvalidValue, /must be positive/)
    end
  end

  describe "#consume_reserved!" do
    it "turns a reservation into a deduction, lowering both balances" do
      part = build(quantity_on_hand: 10, quantity_reserved: 3).consume_reserved!(3)

      expect(part.quantity_on_hand).to eq(7)
      expect(part.quantity_reserved).to eq(0)
    end

    it "consumes only part of a larger reservation" do
      part = build(quantity_on_hand: 10, quantity_reserved: 5).consume_reserved!(2)

      expect(part.quantity_on_hand).to eq(8)
      expect(part.quantity_reserved).to eq(3)
    end

    it "refuses to consume more than is reserved" do
      expect { build(quantity_on_hand: 10, quantity_reserved: 2).consume_reserved!(3) }
        .to raise_error(Domain::Shared::Errors::BusinessRuleViolation, /reserved/)
    end

    it "rejects a non-positive movement" do
      expect { build(quantity_reserved: 5).consume_reserved!(0) }
        .to raise_error(Domain::Shared::Errors::InvalidValue, /must be positive/)
    end
  end

  describe "#release!" do
    it "gives a reservation back to the available balance" do
      part = build(quantity_on_hand: 10, quantity_reserved: 4).release!(3)

      expect(part.quantity_reserved).to eq(1)
      expect(part.quantity_on_hand).to eq(10)
    end

    it "refuses to release more than is reserved" do
      expect { build(quantity_on_hand: 10, quantity_reserved: 2).release!(3) }
        .to raise_error(Domain::Shared::Errors::BusinessRuleViolation, /reserved/)
    end

    it "rejects a non-positive movement" do
      expect { build(quantity_reserved: 5).release!(-1) }
        .to raise_error(Domain::Shared::Errors::InvalidValue, /must be positive/)
    end
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

  describe "#revise" do
    it "carries the reserved balance through unchanged" do
      part = build(quantity_on_hand: 10, quantity_reserved: 4)
        .revise(description: "Filtro de óleo sintético")

      expect(part.quantity_reserved).to eq(4)
      expect(part.description).to eq("Filtro de óleo sintético")
    end
  end

  describe "#below_minimum?" do
    it "flags a part that fell under its reorder point" do
      expect(build(quantity_on_hand: 3, minimum_stock: 4)).to be_below_minimum
    end

    it "does not flag a part sitting exactly on its reorder point" do
      expect(build(quantity_on_hand: 4, minimum_stock: 4)).not_to be_below_minimum
    end

    it "ignores reservations — it is about the physical balance and the reorder point" do
      expect(build(quantity_on_hand: 10, quantity_reserved: 9, minimum_stock: 4)).not_to be_below_minimum
    end
  end

  it "requires a SKU and a description" do
    expect { build(sku: "") }
      .to raise_error(Domain::Shared::Errors::InvalidValue, /SKU is required/)
    expect { build(description: " ") }
      .to raise_error(Domain::Shared::Errors::InvalidValue, /description is required/)
  end

  describe "validation of the reserved balance" do
    it "rejects a negative reserved balance" do
      expect { build(quantity_reserved: -1) }
        .to raise_error(Domain::Shared::Errors::InvalidValue, /reserved stock cannot be negative/)
    end

    it "rejects a reservation larger than the balance on hand" do
      expect { build(quantity_on_hand: 5, quantity_reserved: 6) }
        .to raise_error(Domain::Shared::Errors::InvalidValue, /reserved stock cannot exceed/)
    end
  end
end
