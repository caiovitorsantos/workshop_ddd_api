require "rails_helper"

RSpec.describe Domain::Registry::LicensePlate do
  subject(:described) { described_class }

  it "accepts the legacy format and normalises separators and case" do
    expect(described.parse("abc-1234").code).to eq("ABC1234")
  end

  it "accepts the Mercosur format" do
    plate = described.parse("ABC1D23")

    expect(plate).to be_mercosur
    expect(plate.formatted).to eq("ABC1D23")
  end

  it "adds the dash back when formatting a legacy plate" do
    expect(described.parse("ABC1234").formatted).to eq("ABC-1234")
  end

  it "rejects a plate that matches neither pattern" do
    expect { described.parse("AB12345") }
      .to raise_error(Domain::Shared::Errors::InvalidValue, /ABC1234 or ABC1D23/)
  end

  it "rejects a blank plate" do
    expect { described.parse("   ") }
      .to raise_error(Domain::Shared::Errors::InvalidValue, /required/)
  end
end
