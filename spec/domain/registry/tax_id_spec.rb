require "rails_helper"

# Pure domain spec: no database, no HTTP, no Rails fixtures. This is the payoff
# of keeping the domain free of ActiveRecord — these run in milliseconds.
RSpec.describe Domain::Registry::TaxId do
  subject(:described) { described_class }

  describe "CPF" do
    it "accepts a valid CPF, formatted or raw" do
      expect(described.parse("529.982.247-25").number).to eq("52998224725")
      expect(described.parse("52998224725")).to be_cpf
    end

    it "rejects a CPF with wrong check digits" do
      expect { described.parse("529.982.247-26") }
        .to raise_error(Domain::Shared::Errors::InvalidValue, /invalid CPF/)
    end

    it "rejects repeated digits, which pass the checksum but are not real" do
      expect { described.parse("111.111.111-11") }
        .to raise_error(Domain::Shared::Errors::InvalidValue, /invalid CPF/)
    end

    it "formats for display" do
      expect(described.parse("52998224725").formatted).to eq("529.982.247-25")
    end
  end

  describe "CNPJ" do
    it "accepts a valid CNPJ" do
      expect(described.parse("11.222.333/0001-81")).to be_cnpj
    end

    it "rejects a CNPJ with wrong check digits" do
      expect { described.parse("11.222.333/0001-82") }
        .to raise_error(Domain::Shared::Errors::InvalidValue, /invalid CNPJ/)
    end

    it "formats for display" do
      expect(described.parse("11222333000181").formatted).to eq("11.222.333/0001-81")
    end
  end

  describe "malformed input" do
    it "rejects a blank document" do
      expect { described.parse("") }
        .to raise_error(Domain::Shared::Errors::InvalidValue, /required/)
    end

    it "rejects a document with the wrong number of digits" do
      expect { described.parse("12345") }
        .to raise_error(Domain::Shared::Errors::InvalidValue, /11 \(CPF\) or 14 \(CNPJ\)/)
    end
  end

  describe "value semantics" do
    it "compares by value, not by identity" do
      expect(described.parse("529.982.247-25")).to eq(described.parse("52998224725"))
    end

    it "is frozen after construction" do
      expect(described.parse("52998224725")).to be_frozen
    end

    it "masks all but the last four digits for logging" do
      expect(described.parse("52998224725").masked).to eq("*******4725")
    end
  end
end
