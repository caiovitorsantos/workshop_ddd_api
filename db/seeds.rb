# Seed data for local development and for the Phase 1 demo video.
#
#   bin/rails db:seed
#   docker compose exec api bin/rails db:seed
#
# Idempotent: running it twice does not duplicate anything.

Records = Infrastructure::Persistence::Records

puts "Seeding users..."

users = Infrastructure::Persistence::Repositories::UsersInActiveRecord.new

{
  "gerente@oficina.local"   => { name: "Gabriela Gerente",  role: :manager },
  "atendente@oficina.local" => { name: "Alberto Atendente", role: :front_desk },
  "mecanico@oficina.local"  => { name: "Marcos Mecânico",   role: :mechanic }
}.each do |email, attrs|
  next if users.find_by_email(email)

  users.save(
    Domain::Identity::User.new(
      name: attrs[:name], email: email, role: attrs[:role],
      password_digest: "placeholder"
    ),
    password: ENV.fetch("SEED_PASSWORD", "oficina123")
  )
end

puts "Seeding the service catalog..."

[
  { name: "Troca de óleo",        price_cents: 12_000, estimated_minutes: 30 },
  { name: "Alinhamento",          price_cents: 9_000,  estimated_minutes: 45 },
  { name: "Balanceamento",        price_cents: 8_000,  estimated_minutes: 40 },
  { name: "Revisão completa",     price_cents: 45_000, estimated_minutes: 240 },
  { name: "Troca de pastilhas",   price_cents: 18_000, estimated_minutes: 90 }
].each do |attrs|
  Records::Service.find_or_create_by!(name: attrs[:name]) do |service|
    service.price_cents       = attrs[:price_cents]
    service.estimated_minutes = attrs[:estimated_minutes]
  end
end

puts "Seeding the parts inventory..."

[
  { sku: "OL-5W30",  description: "Óleo sintético 5W30 (1L)", price_cents: 5_500,  quantity_on_hand: 40, minimum_stock: 10 },
  { sku: "FIL-OL01", description: "Filtro de óleo",           price_cents: 4_500,  quantity_on_hand: 25, minimum_stock: 5 },
  { sku: "FIL-AR01", description: "Filtro de ar",             price_cents: 6_200,  quantity_on_hand: 18, minimum_stock: 5 },
  { sku: "PAST-D01", description: "Pastilha de freio diant.", price_cents: 21_000, quantity_on_hand: 8,  minimum_stock: 4 },
  { sku: "VELA-04",  description: "Jogo de velas (4un)",      price_cents: 15_000, quantity_on_hand: 3,  minimum_stock: 6 }
].each do |attrs|
  Records::Part.find_or_create_by!(sku: attrs[:sku]) do |part|
    part.assign_attributes(attrs.except(:sku))
  end
end

puts "Seeding customers and vehicles..."

customers = Infrastructure::Persistence::Repositories::CustomersInActiveRecord.new

[
  { tax_id: "52998224725",   name: "Maria Souza",         email: "maria@example.com",  phone: "11988887777",
    vehicle: { plate: "ABC1D23", make: "Volkswagen", model: "Gol",    year: 2019 } },
  { tax_id: "11144477735",   name: "João Pereira",        email: "joao@example.com",   phone: "11977776666",
    vehicle: { plate: "XYZ9876", make: "Fiat",       model: "Argo",   year: 2021 } },
  { tax_id: "11222333000181", name: "Transportes Delta LTDA", email: "frota@delta.example", phone: "1133334444",
    vehicle: { plate: "DEF4G56", make: "Mercedes",   model: "Sprinter", year: 2022 } }
].each do |attrs|
  tax_id = Domain::Registry::TaxId.parse(attrs[:tax_id])
  customer = customers.find_by_tax_id(tax_id) || customers.save(
    Domain::Registry::Customer.new(
      tax_id: tax_id, name: attrs[:name], email: attrs[:email], phone: attrs[:phone]
    )
  )

  Records::Vehicle.find_or_create_by!(plate: attrs[:vehicle][:plate]) do |vehicle|
    vehicle.assign_attributes(attrs[:vehicle].except(:plate).merge(customer_id: customer.id))
  end
end

puts "Done. Sign in with gerente@oficina.local / #{ENV.fetch('SEED_PASSWORD', 'oficina123')}"
