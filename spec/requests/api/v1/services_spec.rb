require "swagger_helper"

RSpec.describe "api/v1/services", type: :request do
  let(:user) { create_user }
  let(:Authorization) { "Bearer #{Infrastructure::Auth::JwtToken.issue(user)}" }
  let(:auth_headers) { { "Authorization" => send(:Authorization) } }

  path "/api/v1/services" do
    post "Adds a service to the catalog" do
      tags "Services"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          service: {
            type: :object,
            properties: {
              name: { type: :string, example: "Troca de óleo" },
              description: { type: :string },
              price: { type: :string, example: "120.00" },
              estimated_minutes: { type: :integer, example: 30 }
            },
            required: %w[name price]
          }
        },
        required: [ "service" ]
      }

      response "201", "service added" do
        let(:body) do
          { service: { name: "Troca de óleo", price: "120.00", estimated_minutes: 30 } }
        end

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload["price"]).to eq("120.0")
          expect(payload["active"]).to be(true)
        end
      end

      response "409", "name already in the catalog" do
        schema "$ref" => "#/components/schemas/Error"

        before { create_service(name: "Troca de óleo") }

        let(:body) { { service: { name: "Troca de óleo", price: "99.00" } } }

        run_test!
      end

      response "422", "estimated duration must be positive" do
        schema "$ref" => "#/components/schemas/Error"

        let(:body) { { service: { name: "Alinhamento", price: "90", estimated_minutes: 0 } } }

        run_test!
      end
    end

    get "Lists the catalog" do
      tags "Services"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :include_retired, in: :query, type: :boolean, required: false,
                description: "Include retired services (default: active only)"

      response "200", "active services" do
        before do
          create_service(name: "Troca de óleo")
          create_service(name: "Serviço aposentado", active: false)
        end

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload["data"].map { |s| s["name"] }).to eq([ "Troca de óleo" ])
        end
      end
    end
  end

  describe "retiring beats deleting" do
    it "keeps a retired service out of the catalog but on the books" do
      service = create_service(name: "Serviço antigo")

      post "/api/v1/services/#{service.id}/retire", headers: auth_headers
      expect(JSON.parse(response.body)["active"]).to be(false)

      get "/api/v1/services", headers: auth_headers
      expect(JSON.parse(response.body)["data"]).to be_empty

      get "/api/v1/services", params: { include_retired: true }, headers: auth_headers
      expect(JSON.parse(response.body)["data"].size).to eq(1)
    end

    it "refuses to add a retired service to an order" do
      retired = create_service(active: false)
      order   = Application::Workshop::OpenServiceOrder.call(
        orders: orders, vehicles: vehicles, customers: customers, vehicle_id: create_vehicle.id
      ).value

      post "/api/v1/service_orders/#{order.id}/add_service",
           params: { item: { service_id: retired.id } }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to match(/no longer offered/)
    end
  end

  describe "pricing" do
    # The reason ServiceItem copies the price instead of pointing at the catalog.
    it "does not disturb a quote that was already sent" do
      service = create_service(price: 120)
      order   = order_awaiting_approval(service: service)

      patch "/api/v1/services/#{service.id}",
            params: { service: { price: "500.00" } }, headers: auth_headers
      expect(JSON.parse(response.body)["price"]).to eq("500.0")

      get "/api/v1/service_orders/#{order.id}", headers: auth_headers
      expect(JSON.parse(response.body)["quote"]["labour_total"]).to eq("120.0")
    end
  end
end
