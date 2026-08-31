require "swagger_helper"

RSpec.describe "api/v1/service_orders", type: :request do
  let(:user) { create_user }

  # rswag requires the header to be a `let` named exactly after the parameter,
  # capital and all. In a plain `it` block Ruby would read a bare `Authorization`
  # as a constant, hence `send`.
  let(:Authorization) { "Bearer #{Infrastructure::Auth::JwtToken.issue(user)}" }
  let(:auth_headers) { { "Authorization" => send(:Authorization) } }

  path "/api/v1/service_orders" do
    parameter name: :Authorization, in: :header, type: :string, required: true

    post "Opens a service order" do
      tags "Service orders"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          service_order: {
            type: :object,
            properties: { vehicle_id: { type: :integer, example: 1 } },
            required: [ "vehicle_id" ]
          }
        },
        required: [ "service_order" ]
      }

      response "201", "order opened in 'received'" do
        let(:body) { { service_order: { vehicle_id: create_vehicle.id } } }

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload["status"]).to eq("received")
          expect(payload["status_label"]).to eq("Recebida")
          expect(payload["number"]).to match(/\AOS-\d{6}\z/)
        end
      end

      response "404", "vehicle not registered" do
        schema "$ref" => "#/components/schemas/Error"

        let(:body) { { service_order: { vehicle_id: 999_999 } } }

        run_test!
      end
    end

    get "Lists service orders" do
      tags "Service orders"
      produces "application/json"
      security [ bearer_auth: [] ]
      parameter name: :status, in: :query, type: :string, required: false
      parameter name: :customer_id, in: :query, type: :integer, required: false

      response "200", "order list" do
        before { order_awaiting_approval }

        let(:status) { "awaiting_approval" }

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload["data"].size).to eq(1)
          expect(payload["data"].first).not_to have_key("part_items") # listing is a summary
        end
      end
    end
  end

  path "/api/v1/service_orders/{id}" do
    parameter name: :Authorization, in: :header, type: :string, required: true
    parameter name: :id, in: :path, type: :integer, required: true

    get "Fetches one order with its items and quote" do
      tags "Service orders"
      produces "application/json"
      security [ bearer_auth: [] ]

      response "200", "order found" do
        let(:id) { order_awaiting_approval.id }

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload["quote"]["total"]).to eq("210.0")   # 120 labour + 2 x 45 parts
          expect(payload["service_items"].size).to eq(1)
          expect(payload["part_items"].size).to eq(1)
        end
      end

      response "404", "order not found" do
        schema "$ref" => "#/components/schemas/Error"

        let(:id) { 999_999 }

        run_test!
      end
    end
  end

  path "/api/v1/service_orders/{id}/approve_quote" do
    parameter name: :Authorization, in: :header, type: :string, required: true
    parameter name: :id, in: :path, type: :integer, required: true

    post "Approves the quote and consumes the parts" do
      tags "Service orders"
      produces "application/json"
      security [ bearer_auth: [] ]
      description <<~TEXT
        Pivotal event of the flow: it moves the order into execution AND deducts
        every quoted part from inventory, in a single transaction. If any part
        is short, nothing is approved.
      TEXT

      response "200", "approved, stock deducted" do
        let(:part)  { create_part(on_hand: 10) }
        let(:order) { order_awaiting_approval(part: part, part_quantity: 2) }
        let(:id)    { order.id }

        run_test! do |response|
          expect(JSON.parse(response.body)["status"]).to eq("in_progress")
          expect(parts.find(part.id).quantity_on_hand).to eq(8)
        end
      end

      response "422", "not enough stock — nothing is approved" do
        schema "$ref" => "#/components/schemas/Error"

        let(:part)  { create_part(on_hand: 1) }
        let(:order) { order_awaiting_approval(part: part, part_quantity: 1) }
        let(:id)    { order.id }

        before do
          # Order first: the part was quoted while the unit was still on the
          # shelf. Then someone else takes it. That sequence is the whole point
          # — quoting and approving are separated in time, and stock can vanish
          # in between.
          order
          parts.save(parts.find(part.id).deduct!(1))
        end

        run_test! do |response|
          expect(JSON.parse(response.body)["error"]).to match(/insufficient stock/)
          expect(orders.find(order.id).status).to be_awaiting_approval
        end
      end

      response "409", "order is not awaiting approval" do
        schema "$ref" => "#/components/schemas/Error"

        # A freshly opened order has not been quoted yet.
        let(:id) do
          Application::Workshop::OpenServiceOrder.call(
            orders: orders, vehicles: vehicles, customers: customers,
            vehicle_id: create_vehicle.id
          ).value.id
        end

        run_test!
      end

      response "401", "no token" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { "Bearer nope" }
        let(:id) { order_awaiting_approval.id }

        run_test!
      end
    end
  end

  # The full journey, in one spec, as the video will demo it.
  describe "the whole life cycle" do
    it "walks an order from opening to delivery" do
      part    = create_part(on_hand: 10)
      service = create_service(price: 120)
      vehicle = create_vehicle
      headers = auth_headers

      post "/api/v1/service_orders",
           params: { service_order: { vehicle_id: vehicle.id } }, headers: headers
      expect(response).to have_http_status(:created)
      id = JSON.parse(response.body)["id"]

      post "/api/v1/service_orders/#{id}/add_service",
           params: { item: { service_id: service.id } }, headers: headers
      post "/api/v1/service_orders/#{id}/add_part",
           params: { item: { part_id: part.id, quantity: 2 } }, headers: headers
      expect(JSON.parse(response.body)["quote"]["total"]).to eq("210.0")

      post "/api/v1/service_orders/#{id}/start_diagnosis", headers: headers
      post "/api/v1/service_orders/#{id}/send_quote",
           params: { diagnosis: "Óleo vencido e filtro saturado" }, headers: headers
      expect(JSON.parse(response.body)["status"]).to eq("awaiting_approval")

      post "/api/v1/service_orders/#{id}/approve_quote", headers: headers
      expect(JSON.parse(response.body)["status"]).to eq("in_progress")
      expect(parts.find(part.id).quantity_on_hand).to eq(8)

      post "/api/v1/service_orders/#{id}/complete", headers: headers
      post "/api/v1/service_orders/#{id}/deliver", headers: headers

      payload = JSON.parse(response.body)
      expect(payload["status"]).to eq("delivered")
      expect(payload["status_label"]).to eq("Entregue")
      expect(payload["timeline"]["delivered_at"]).to be_present
    end

    it "refuses to add items once the quote is with the customer" do
      order   = order_awaiting_approval
      service = create_service
      headers = auth_headers

      post "/api/v1/service_orders/#{order.id}/add_service",
           params: { item: { service_id: service.id } }, headers: headers

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body)["error"]).to match(/cannot add services/)
    end

    it "cancels an order the customer never approved" do
      order   = order_awaiting_approval
      headers = auth_headers

      post "/api/v1/service_orders/#{order.id}/reject_quote",
           params: { reason: "muito caro" }, headers: headers

      expect(JSON.parse(response.body)["status"]).to eq("cancelled")
    end

    it "refuses to skip states" do
      order   = order_awaiting_approval
      headers = auth_headers

      post "/api/v1/service_orders/#{order.id}/deliver", headers: headers

      expect(response).to have_http_status(:conflict)
    end
  end
end
