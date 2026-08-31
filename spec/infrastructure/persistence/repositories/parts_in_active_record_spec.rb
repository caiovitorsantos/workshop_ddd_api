require "rails_helper"

RSpec.describe Infrastructure::Persistence::Repositories::PartsInActiveRecord do
  subject(:repository) { described_class.new }

  def new_part(**overrides)
    Domain::Inventory::Part.new(
      **{ sku: "FIL-RES01", description: "Filtro de óleo",
          unit_price: Domain::Shared::Money.from_amount(30),
          quantity_on_hand: 10, minimum_stock: 2 }.merge(overrides)
    )
  end

  it "round-trips the reserved balance" do
    part = repository.save(new_part)
    repository.save(part.reserve!(4))

    reloaded = repository.find(part.id)

    expect(reloaded.quantity_reserved).to eq(4)
    expect(reloaded.available_quantity).to eq(6)
  end

  it "round-trips a consumed reservation" do
    part = repository.save(new_part)
    repository.save(part.reserve!(4))
    repository.save(repository.find(part.id).consume_reserved!(3))

    reloaded = repository.find(part.id)

    expect(reloaded.quantity_on_hand).to eq(7)
    expect(reloaded.quantity_reserved).to eq(1)
  end
end
