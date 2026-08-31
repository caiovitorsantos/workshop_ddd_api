require "rails_helper"

# The Swagger documentation is *generated from the request specs* (rswag). That
# solves the classic API-documentation problem: the docs cannot drift from the
# real behaviour, because if they drift the test fails.
#
#   bundle exec rake rswag:specs:swaggerize   # regenerates swagger/v1/swagger.yaml
#   http://localhost:3000/api-docs            # UI
RSpec.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s

  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "Workshop Management API",
        version: "v1",
        description: <<~DESCRIPTION
          Sistema Integrado de Atendimento e Execução de Serviços.

          MVP backend for a mid-sized auto repair shop, modelled with
          Domain-Driven Design and organised in four layers (Interface,
          Application, Domain, Infrastructure).

          Authentication: every administrative route requires
          `Authorization: Bearer <token>`. Get a token from POST /api/v1/session.
          The only public route is the customer's order tracking endpoint.
        DESCRIPTION
      },
      paths: {},
      servers: [
        { url: "http://localhost:3000", description: "Local environment (docker compose)" }
      ],
      components: {
        securitySchemes: {
          bearer_auth: { type: :http, scheme: :bearer, bearerFormat: :JWT }
        },
        schemas: {
          Error: {
            type: :object,
            properties: { error: { type: :string, example: "invalid CPF" } },
            required: [ "error" ]
          },
          Customer: {
            type: :object,
            properties: {
              id: { type: :integer, example: 1 },
              tax_id: { type: :string, example: "529.982.247-25" },
              tax_id_kind: { type: :string, enum: %w[cpf cnpj] },
              name: { type: :string, example: "Maria Souza" },
              email: { type: :string, nullable: true, example: "maria@example.com" },
              phone: { type: :string, nullable: true, example: "11988887777" }
            },
            required: %w[id tax_id tax_id_kind name]
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end
