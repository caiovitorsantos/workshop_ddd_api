require "rails_helper"

RSpec.describe Domain::Catalog::Service do
  def build(**overrides)
    described_class.new(
      **{ name: "Troca de óleo",
          price: Domain::Shared::Money.from_amount(120),
          estimated_minutes: 30 }.merge(overrides)
    )
  end

  it "is active by default" do
    expect(build).to be_active
  end

  it "can be retired from the catalog without being deleted" do
    expect(build(active: false)).not_to be_active
  end

  it "requires a name and a price" do
    expect { build(name: "  ") }
      .to raise_error(Domain::Shared::Errors::InvalidValue, /name is required/)
    expect { build(price: nil) }
      .to raise_error(Domain::Shared::Errors::InvalidValue, /price is required/)
  end

  describe "estimated duration" do
    it "is optional — not every service has a reliable estimate yet" do
      expect { build(estimated_minutes: nil) }.not_to raise_error
    end

    it "must be positive when given" do
      expect { build(estimated_minutes: 0) }
        .to raise_error(Domain::Shared::Errors::InvalidValue, /must be positive/)
    end
  end
end
