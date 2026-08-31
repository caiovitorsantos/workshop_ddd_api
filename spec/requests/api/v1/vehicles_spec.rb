require "swagger_helper"

RSpec.describe "api/v1/vehicles", type: :request do
  let(:user) { create_user }
  let(:Authorization) { "Bearer #{Infrastructure::Auth::JwtToken.issue(user)}" }
  let(:auth_headers) { { "Authorization" => send(:Authorization) } }

  path "/api/v1/customers/{customer_id}/vehicles" do
    parameter name: :Authorization, in: :header, type: :string, required: true
    parameter name: :customer_id, in: :path, type: :integer, required: true

    post "Registers a vehicle for a customer" do
      tags "Vehicles"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          vehicle: {
            type: :object,
            properties: {
              plate: { type: :string, example: "ABC1D23" },
              make: { type: :string, example: "Volkswagen" },
              model: { type: :string, example: "Gol" },
              year: { type: :integer, example: 2019 }
            },
            required: %w[plate make model year]
          }
        },
        required: [ "vehicle" ]
      }

      response "201", "vehicle registered" do
        let(:customer_id) { create_customer.id }
        let(:body) do
          { vehicle: { plate: "abc-1d23", make: "Volkswagen", model: "Gol", year: 2019 } }
        end

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload["plate"]).to eq("ABC1D23") # normalised by the value object
          expect(payload["description"]).to eq("Volkswagen Gol 2019 (ABC1D23)")
        end
      end

      response "422", "malformed plate" do
        schema "$ref" => "#/components/schemas/Error"

        let(:customer_id) { create_customer.id }
        let(:body) { { vehicle: { plate: "AB12345", make: "VW", model: "Gol", year: 2019 } } }

        run_test! do |response|
          expect(JSON.parse(response.body)["error"]).to match(/ABC1234 or ABC1D23/)
        end
      end

      response "409", "plate already registered" do
        schema "$ref" => "#/components/schemas/Error"

        let(:customer_id) { create_customer.id }
        let(:body) { { vehicle: { plate: "ABC1D23", make: "VW", model: "Gol", year: 2019 } } }

        before { create_vehicle(plate: "ABC1D23") }

        run_test!
      end

      response "404", "customer does not exist" do
        schema "$ref" => "#/components/schemas/Error"

        let(:customer_id) { 999_999 }
        let(:body) { { vehicle: { plate: "ABC1D23", make: "VW", model: "Gol", year: 2019 } } }

        run_test!
      end
    end

    get "Lists a customer's vehicles" do
      tags "Vehicles"
      produces "application/json"
      security [ bearer_auth: [] ]

      response "200", "vehicle list" do
        let(:customer) { create_customer }
        let(:customer_id) { customer.id }

        before { create_vehicle(customer: customer) }

        run_test! do |response|
          expect(JSON.parse(response.body)["data"].size).to eq(1)
        end
      end
    end
  end

  path "/api/v1/vehicles/{id}/transfer" do
    parameter name: :Authorization, in: :header, type: :string, required: true
    parameter name: :id, in: :path, type: :integer, required: true

    post "Transfers the vehicle to another customer" do
      tags "Vehicles"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      description "Ownership is a business command, not an editable field."

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { customer_id: { type: :integer } },
        required: [ "customer_id" ]
      }

      response "200", "transferred" do
        let(:vehicle) { create_vehicle }
        let(:id) { vehicle.id }
        let(:new_owner) { create_customer(name: "João Pereira") }
        let(:body) { { customer_id: new_owner.id } }

        run_test! do |response|
          expect(JSON.parse(response.body)["customer_id"]).to eq(new_owner.id)
        end
      end

      response "404", "new owner does not exist" do
        schema "$ref" => "#/components/schemas/Error"

        let(:id) { create_vehicle.id }
        let(:body) { { customer_id: 999_999 } }

        run_test!
      end
    end
  end

  describe "corrections" do
    it "fixes a typo in the description without touching the plate" do
      vehicle = create_vehicle(plate: "ABC1D23")

      patch "/api/v1/vehicles/#{vehicle.id}",
            params: { vehicle: { model: "Gol G7", plate: "ZZZ9Z99" } }, headers: auth_headers

      payload = JSON.parse(response.body)
      expect(payload["model"]).to eq("Gol G7")
      # The plate is the natural identity: not editable, silently ignored.
      expect(payload["plate"]).to eq("ABC1D23")
    end

    it "rejects an implausible model year" do
      vehicle = create_vehicle

      patch "/api/v1/vehicles/#{vehicle.id}",
            params: { vehicle: { year: 1800 } }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to match(/year must be between/)
    end

    it "refuses to delete a vehicle that has service orders" do
      order = order_awaiting_approval

      delete "/api/v1/vehicles/#{order.vehicle_id}", headers: auth_headers

      expect(response).to have_http_status(:conflict)
    end
  end
end
