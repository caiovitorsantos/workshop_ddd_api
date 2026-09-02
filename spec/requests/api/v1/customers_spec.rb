require "swagger_helper"

# Integration spec written in rswag's DSL: it exercises the real stack
# (controller -> use case -> repository -> PostgreSQL) *and* generates the
# Swagger documentation for these endpoints. One source of truth.
RSpec.describe "api/v1/customers", type: :request do
  let(:user) do
    Infrastructure::Persistence::Repositories::UsersInActiveRecord.new.save(
      Domain::Identity::User.new(
        name: "Ana Atendente", email: "ana@oficina.test",
        role: :front_desk, password_digest: "placeholder"
      ),
      password: "senha-forte-123"
    )
  end

  let(:Authorization) { "Bearer #{Infrastructure::Auth::JwtToken.issue(user)}" }

  path "/api/v1/customers" do
    post "Registers a customer" do
      tags "Customers"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          customer: {
            type: :object,
            properties: {
              tax_id: { type: :string, example: "529.982.247-25" },
              name: { type: :string, example: "Maria Souza" },
              email: { type: :string, example: "maria@example.com" },
              phone: { type: :string, example: "11988887777" }
            },
            required: %w[tax_id name]
          }
        },
        required: [ "customer" ]
      }

      response "201", "customer registered" do
        schema "$ref" => "#/components/schemas/Customer"

        let(:body) { { customer: { tax_id: "529.982.247-25", name: "Maria Souza" } } }

        run_test! do |response|
          expect(JSON.parse(response.body)["tax_id"]).to eq("529.982.247-25")
        end
      end

      response "422", "invalid tax id" do
        schema "$ref" => "#/components/schemas/Error"

        let(:body) { { customer: { tax_id: "111.111.111-11", name: "Fraude" } } }

        run_test! do |response|
          expect(JSON.parse(response.body)["error"]).to match(/invalid CPF/)
        end
      end

      response "409", "tax id already registered" do
        schema "$ref" => "#/components/schemas/Error"

        before do
          Infrastructure::Persistence::Repositories::CustomersInActiveRecord.new.save(
            Domain::Registry::Customer.new(
              tax_id: Domain::Registry::TaxId.parse("52998224725"), name: "Maria Souza"
            )
          )
        end

        let(:body) { { customer: { tax_id: "529.982.247-25", name: "Maria Duplicada" } } }

        run_test!
      end

      response "401", "missing or invalid token" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { "Bearer nao-e-um-token" }
        let(:body) { { customer: { tax_id: "529.982.247-25", name: "Maria Souza" } } }

        run_test!
      end
    end

    get "Lists customers" do
      tags "Customers"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :q, in: :query, type: :string, required: false,
                description: "Searches by name or tax id"

      response "200", "customer list" do
        before { create_customer(tax_id: "52998224725", name: "Maria Souza") }

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["data"].size).to eq(1)
          expect(body["pagination"]["total"]).to eq(1)
        end
      end

      response "200", "search filtered by name" do
        before do
          create_customer(tax_id: "52998224725", name: "Maria Souza")
          create_customer(tax_id: "11144477735", name: "João Pereira")
        end

        let(:q) { "Maria" }

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["data"].map { |c| c["name"] }).to eq([ "Maria Souza" ])
        end
      end
    end
  end

  path "/api/v1/customers/{id}" do
    parameter name: :id, in: :path, type: :integer, required: true

    get "Fetches one customer" do
      tags "Customers"
      produces "application/json"
      security [ bearer_auth: [] ]

      response "200", "customer found" do
        schema "$ref" => "#/components/schemas/Customer"

        let(:id) { create_customer(tax_id: "52998224725", name: "Maria Souza").id }

        run_test! do |response|
          expect(JSON.parse(response.body)["name"]).to eq("Maria Souza")
        end
      end

      response "404", "customer not found" do
        schema "$ref" => "#/components/schemas/Error"

        let(:id) { 999_999 }

        run_test!
      end
    end

    patch "Updates a customer's contact details" do
      tags "Customers"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          customer: {
            type: :object,
            properties: {
              name: { type: :string },
              email: { type: :string },
              phone: { type: :string }
            }
          }
        },
        required: [ "customer" ]
      }

      response "200", "contact details updated" do
        schema "$ref" => "#/components/schemas/Customer"

        let(:id) { create_customer(tax_id: "52998224725", name: "Maria Souza").id }
        let(:body) { { customer: { name: "Maria Souza Lima", email: "maria@example.com" } } }

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload["name"]).to eq("Maria Souza Lima")
          # The tax id is the natural identity and is not editable.
          expect(payload["tax_id"]).to eq("529.982.247-25")
        end
      end

      response "422", "invalid contact details" do
        schema "$ref" => "#/components/schemas/Error"

        let(:id) { create_customer(tax_id: "52998224725", name: "Maria Souza").id }
        let(:body) { { customer: { email: "nao-e-um-email" } } }

        run_test!
      end
    end

    delete "Removes a customer" do
      tags "Customers"
      security [ bearer_auth: [] ]

      response "204", "customer removed" do
        let(:id) { create_customer(tax_id: "52998224725", name: "Maria Souza").id }

        run_test!
      end
    end
  end

  def create_customer(tax_id:, name:)
    Infrastructure::Persistence::Repositories::CustomersInActiveRecord.new.save(
      Domain::Registry::Customer.new(
        tax_id: Domain::Registry::TaxId.parse(tax_id), name: name
      )
    )
  end
end
