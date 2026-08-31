require "rails_helper"

# Money underpins every quote total, so its arithmetic gets its own spec.
RSpec.describe Domain::Shared::Money do
  subject(:described) { described_class }

  it "stores amounts in cents, with no float in sight" do
    expect(described.from_amount("19.99").cents).to eq(1999)
  end

  it "rounds half-cent amounts rather than truncating them" do
    expect(described.from_amount("0.005").cents).to eq(1)
  end

  it "adds without losing a cent across many items" do
    total = 3.times.reduce(described.zero) { |acc, _| acc + described.from_amount("0.10") }

    expect(total).to eq(described.from_amount("0.30"))
  end

  it "multiplies by a quantity" do
    expect(described.from_amount("45.50") * 3).to eq(described.from_amount("136.50"))
  end

  it "reports zero" do
    expect(described.zero).to be_zero
    expect(described.from_amount(1)).not_to be_zero
  end

  it "formats for display in Brazilian reais" do
    expect(described.from_amount("1234.5").to_s).to eq("R$ 1234.50")
  end

  it "converts back to a decimal amount" do
    expect(described.from_amount("19.99").amount).to eq(BigDecimal("19.99"))
  end

  it "rejects a missing amount" do
    expect { described.from_amount(nil) }
      .to raise_error(Domain::Shared::Errors::InvalidValue, /missing/)
  end

  it "rejects a negative amount — nothing in this domain costs less than nothing" do
    expect { described.new(cents: -1) }
      .to raise_error(Domain::Shared::Errors::InvalidValue, /cannot be negative/)
  end

  it "compares by value and is frozen" do
    expect(described.from_amount(10)).to eq(described.new(cents: 1000))
    expect(described.zero).to be_frozen
  end
end
