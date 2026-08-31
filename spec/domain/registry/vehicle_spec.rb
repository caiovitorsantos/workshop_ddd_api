require "rails_helper"

RSpec.describe Domain::Registry::Vehicle do
  def plate(code) = Domain::Registry::LicensePlate.parse(code)

  def build(**overrides)
    described_class.new(
      **{ plate: plate("ABC1D23"), make: "Volkswagen", model: "Gol",
          year: 2019, customer_id: 1 }.merge(overrides)
    )
  end

  it "describes itself the way the front desk reads it out loud" do
    expect(build.description).to eq("Volkswagen Gol 2019 (ABC1D23)")
  end

  it "requires make, model and an owner" do
    expect { build(make: " ") }
      .to raise_error(Domain::Shared::Errors::InvalidValue, /make is required/)
    expect { build(model: "") }
      .to raise_error(Domain::Shared::Errors::InvalidValue, /model is required/)
    expect { build(customer_id: nil) }
      .to raise_error(Domain::Shared::Errors::InvalidValue, /owner is required/)
  end

  describe "model year" do
    it "accepts next year, since dealerships sell ahead of the calendar" do
      expect { build(year: Time.current.year + 1) }.not_to raise_error
    end

    it "rejects a year beyond next year" do
      expect { build(year: Time.current.year + 2) }
        .to raise_error(Domain::Shared::Errors::InvalidValue, /year must be between/)
    end

    it "rejects a year before cars existed in any meaningful number" do
      expect { build(year: 1899) }
        .to raise_error(Domain::Shared::Errors::InvalidValue, /year must be between/)
    end
  end

  describe "#transfer_to" do
    it "returns a vehicle owned by someone else, leaving the original alone" do
      original = build(customer_id: 1)
      transferred = original.transfer_to(2)

      expect(transferred.customer_id).to eq(2)
      expect(original.customer_id).to eq(1)
      expect(transferred.plate).to eq(original.plate)
    end
  end

  describe "#correct_details" do
    it "fixes the description, leaving the plate and owner alone" do
      original  = build(make: "Volkswagem", customer_id: 1)
      corrected = original.correct_details(make: "Volkswagen", model: "Gol G7")

      expect(corrected.make).to eq("Volkswagen")
      expect(corrected.model).to eq("Gol G7")
      expect(corrected.plate).to eq(original.plate)
      expect(corrected.customer_id).to eq(1)
    end

    it "keeps whatever it is not asked to change" do
      corrected = build(year: 2019).correct_details(model: "Polo")

      expect(corrected.year).to eq(2019)
    end

    it "still refuses an implausible year" do
      expect { build.correct_details(year: 1800) }
        .to raise_error(Domain::Shared::Errors::InvalidValue, /year must be between/)
    end
  end
end
