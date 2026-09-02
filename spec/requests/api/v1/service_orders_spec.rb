require "swagger_helper"

RSpec.describe "api/v1/service_orders", type: :request do
  let(:user) { create_user }

  # rswag requires the header to be a `let` named exactly after the parameter,
  # capital and all. In a plain `it` block Ruby would read a bare `Authorization`
  # as a constant, hence `send`.
  let(:Authorization) { "Bearer #{Infrastructure::Auth::JwtToken.issue(user)}" }
  let(:auth_headers) { { "Authorization" => send(:Authorization) } }

  path "/api/v1/service_orders" do
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

  path "/api/v1/service_orders/{id}/add_service" do
    parameter name: :id, in: :path, type: :integer, required: true

    post "Adds a catalogued service to the order and regenerates the quote" do
      tags "Service orders"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      description <<~TEXT
        The service's name and price are copied from the Catalog into the order
        line, so a later catalogue price change cannot rewrite a quote the
        customer has already seen. Every add recomputes the quote
        (labour_total + parts_total). Allowed only while the order is a draft.
      TEXT

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          item: {
            type: :object,
            properties: {
              service_id: { type: :integer, example: 1 },
              quantity: { type: :integer, example: 1 }
            },
            required: %w[service_id]
          }
        },
        required: [ "item" ]
      }

      response "200", "service added, quote regenerated" do
        let(:service) { create_service(price: 120) }
        let(:id)      { draft_order.id }
        let(:body)    { { item: { service_id: service.id, quantity: 1 } } }

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload["service_items"].size).to eq(1)
          expect(payload["quote"]["labour_total"]).to eq("120.0")
          expect(payload["quote"]["total"]).to eq("120.0")
        end
      end

      response "404", "service not in the catalogue" do
        schema "$ref" => "#/components/schemas/Error"

        let(:id)   { draft_order.id }
        let(:body) { { item: { service_id: 999_999 } } }

        run_test!
      end

      response "422", "service is retired" do
        schema "$ref" => "#/components/schemas/Error"

        let(:service) { create_service(active: false) }
        let(:id)      { draft_order.id }
        let(:body)    { { item: { service_id: service.id } } }

        run_test! do |response|
          expect(JSON.parse(response.body)["error"]).to match(/no longer offered/)
        end
      end
    end
  end

  path "/api/v1/service_orders/{id}/add_part" do
    parameter name: :id, in: :path, type: :integer, required: true

    post "Adds a part to the order and reserves its stock" do
      tags "Service orders"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      description <<~TEXT
        First phase of the two-phase stock flow: the part is reserved, not yet
        deducted. Approval turns the reservation into a deduction; rejecting or
        cancelling the order releases it. A part cannot be added when its
        available balance (on hand minus already reserved) is short.
      TEXT

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          item: {
            type: :object,
            properties: {
              part_id: { type: :integer, example: 1 },
              quantity: { type: :integer, example: 2 }
            },
            required: %w[part_id quantity]
          }
        },
        required: [ "item" ]
      }

      response "200", "part added, stock reserved" do
        let(:part) { create_part(on_hand: 10) }
        let(:id) do
          Application::Workshop::OpenServiceOrder.call(
            orders: orders, vehicles: vehicles, customers: customers,
            vehicle_id: create_vehicle.id
          ).value.id
        end
        let(:body) { { item: { part_id: part.id, quantity: 3 } } }

        run_test! do |response|
          expect(JSON.parse(response.body)["part_items"].size).to eq(1)
          expect(parts.find(part.id).quantity_reserved).to eq(3)
          expect(parts.find(part.id).quantity_on_hand).to eq(10)
        end
      end

      response "422", "not enough stock to reserve" do
        schema "$ref" => "#/components/schemas/Error"

        let(:part) { create_part(on_hand: 1) }
        let(:id) do
          Application::Workshop::OpenServiceOrder.call(
            orders: orders, vehicles: vehicles, customers: customers,
            vehicle_id: create_vehicle.id
          ).value.id
        end
        let(:body) { { item: { part_id: part.id, quantity: 2 } } }

        run_test! do |response|
          expect(JSON.parse(response.body)["error"]).to match(/insufficient stock/)
          expect(parts.find(part.id).quantity_reserved).to eq(0)
        end
      end
    end
  end

  path "/api/v1/service_orders/{id}/start_diagnosis" do
    parameter name: :id, in: :path, type: :integer, required: true

    post "Moves the order into diagnosis" do
      tags "Service orders"
      produces "application/json"
      security [ bearer_auth: [] ]
      description <<~TEXT
        received -> in_diagnosis. The status moves because the mechanic started
        work, not because anyone wrote the field — there is no endpoint that
        sets `status` directly.
      TEXT

      response "200", "diagnosis started" do
        let(:id) { draft_order.id }

        run_test! do |response|
          expect(JSON.parse(response.body)["status"]).to eq("in_diagnosis")
        end
      end

      response "409", "order is not in 'received'" do
        schema "$ref" => "#/components/schemas/Error"

        let(:id) { order_awaiting_approval.id }

        run_test!
      end
    end
  end

  path "/api/v1/service_orders/{id}/send_quote" do
    parameter name: :id, in: :path, type: :integer, required: true

    post "Closes the diagnosis and sends the quote to the customer" do
      tags "Service orders"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      description <<~TEXT
        in_diagnosis -> awaiting_approval. Requires a diagnosis and at least one
        service or part on the order. From here the order is out of the
        workshop's hands until the customer decides.
      TEXT

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { diagnosis: { type: :string, example: "Óleo vencido e filtro saturado" } },
        required: [ "diagnosis" ]
      }

      response "200", "quote sent" do
        let(:id)   { order_in_diagnosis.id }
        let(:body) { { diagnosis: "Óleo vencido e filtro saturado" } }

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload["status"]).to eq("awaiting_approval")
          expect(payload["diagnosis"]).to eq("Óleo vencido e filtro saturado")
        end
      end

      response "422", "no diagnosis given" do
        schema "$ref" => "#/components/schemas/Error"

        let(:id)   { order_in_diagnosis.id }
        let(:body) { { diagnosis: "" } }

        run_test! do |response|
          expect(JSON.parse(response.body)["error"]).to match(/diagnosis/)
        end
      end
    end
  end

  path "/api/v1/service_orders/{id}/approve_quote" do
    parameter name: :id, in: :path, type: :integer, required: true

    post "Approves the quote and consumes the parts" do
      tags "Service orders"
      produces "application/json"
      security [ bearer_auth: [] ]
      description <<~TEXT
        Pivotal event of the flow: it moves the order into execution AND turns
        every quoted part's reservation into a real deduction, in a single
        transaction. The parts were reserved when they were added, so approval
        never fails for want of stock — only on the status transition.
      TEXT

      response "200", "approved, stock deducted" do
        let(:part)  { create_part(on_hand: 10) }
        let(:order) { order_awaiting_approval(part: part, part_quantity: 2) }
        let(:id)    { order.id }

        run_test! do |response|
          expect(JSON.parse(response.body)["status"]).to eq("in_progress")
          expect(parts.find(part.id).quantity_on_hand).to eq(8)
          expect(parts.find(part.id).quantity_reserved).to eq(0)
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

  path "/api/v1/service_orders/{id}/reject_quote" do
    parameter name: :id, in: :path, type: :integer, required: true

    post "The customer refused the quote" do
      tags "Service orders"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      description <<~TEXT
        awaiting_approval -> cancelled, releasing every reserved part back to the
        shelf in the same transaction. Distinct from cancel: this one is a sale
        lost to price.
      TEXT

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { reason: { type: :string, example: "muito caro" } }
      }

      response "200", "quote rejected, parts released" do
        let(:part)  { create_part(on_hand: 10) }
        let(:order) { order_awaiting_approval(part: part, part_quantity: 3) }
        let(:id)    { order.id }
        let(:body)  { { reason: "muito caro" } }

        run_test! do |response|
          expect(JSON.parse(response.body)["status"]).to eq("cancelled")
          expect(parts.find(part.id).quantity_reserved).to eq(0)
        end
      end

      response "409", "order is already in progress" do
        schema "$ref" => "#/components/schemas/Error"

        let(:id)   { order_in_progress.id }
        let(:body) { {} }

        run_test!
      end
    end
  end

  path "/api/v1/service_orders/{id}/complete" do
    parameter name: :id, in: :path, type: :integer, required: true

    post "Marks the work finished" do
      tags "Service orders"
      produces "application/json"
      security [ bearer_auth: [] ]
      description "in_progress -> completed, stamping completed_at."

      response "200", "work completed" do
        let(:id) { order_in_progress.id }

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload["status"]).to eq("completed")
          expect(payload["timeline"]["completed_at"]).to be_present
        end
      end

      response "409", "order is not in progress" do
        schema "$ref" => "#/components/schemas/Error"

        let(:id) { order_awaiting_approval.id }

        run_test!
      end
    end
  end

  path "/api/v1/service_orders/{id}/deliver" do
    parameter name: :id, in: :path, type: :integer, required: true

    post "Hands the vehicle back to the customer" do
      tags "Service orders"
      produces "application/json"
      security [ bearer_auth: [] ]
      description <<~TEXT
        completed -> delivered. Closes the operation and opens the history:
        delivered_at is stamped and the execution time becomes available.
      TEXT

      response "200", "vehicle delivered" do
        let(:id) { order_completed.id }

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload["status"]).to eq("delivered")
          expect(payload["timeline"]["delivered_at"]).to be_present
        end
      end

      response "409", "order is not completed" do
        schema "$ref" => "#/components/schemas/Error"

        let(:id) { order_in_progress.id }

        run_test!
      end
    end
  end

  path "/api/v1/service_orders/{id}/cancel" do
    parameter name: :id, in: :path, type: :integer, required: true

    post "The workshop ends the order" do
      tags "Service orders"
      consumes "application/json"
      produces "application/json"
      security [ bearer_auth: [] ]
      description <<~TEXT
        Wrong vehicle, duplicate entry, customer gave up. Allowed only before
        approval (received, in_diagnosis, awaiting_approval); any reserved parts
        are released. Distinct from reject_quote: nobody refused a price here.
      TEXT

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { reason: { type: :string, example: "veículo errado" } }
      }

      response "200", "order cancelled" do
        let(:id)   { draft_order.id }
        let(:body) { { reason: "veículo errado" } }

        run_test! do |response|
          expect(JSON.parse(response.body)["status"]).to eq("cancelled")
        end
      end

      response "409", "order is already in progress" do
        schema "$ref" => "#/components/schemas/Error"

        let(:id)   { order_in_progress.id }
        let(:body) { {} }

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

    it "cancels an order the customer never approved and releases its parts" do
      part    = create_part(on_hand: 10)
      order   = order_awaiting_approval(part: part, part_quantity: 3)
      headers = auth_headers

      expect(parts.find(part.id).quantity_reserved).to eq(3)

      post "/api/v1/service_orders/#{order.id}/reject_quote",
           params: { reason: "muito caro" }, headers: headers

      expect(JSON.parse(response.body)["status"]).to eq("cancelled")
      expect(parts.find(part.id).quantity_reserved).to eq(0)
      expect(parts.find(part.id).quantity_on_hand).to eq(10)
    end

    it "refuses to skip states" do
      order   = order_awaiting_approval
      headers = auth_headers

      post "/api/v1/service_orders/#{order.id}/deliver", headers: headers

      expect(response).to have_http_status(:conflict)
    end
  end
end
