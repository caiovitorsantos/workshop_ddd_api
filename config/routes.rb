Rails.application.routes.draw do
  # Swagger/OpenAPI documentation, generated from the request specs (rswag).
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      # --- Implemented ------------------------------------------------------
      resource :session, only: [ :create ], controller: "sessions"

      # Registry
      resources :customers do
        resources :vehicles, only: [ :index, :create ]
      end
      resources :vehicles, only: [ :show, :update, :destroy ] do
        # Ownership is a business command, not an editable field.
        member { post :transfer }
      end

      # Catalog
      resources :services do
        # Retiring keeps the history readable; deleting does not.
        member { post :retire }
      end

      # Inventory
      resources :parts do
        # The only way stock goes up. It never goes down here — that happens
        # when a quote is approved.
        member { post :restock }
      end

      # Workshop — the core subdomain.
      #
      # Status changes are *business commands*, not a PATCH on a `status` field.
      # "POST /service_orders/1/approve_quote" says what happened on the shop
      # floor; "PATCH status=in_progress" says nothing, and would hand the state
      # machine over to whoever calls the API.
      resources :service_orders, only: [ :index, :show, :create ] do
        member do
          post :add_service
          post :add_part

          post :start_diagnosis
          post :send_quote
          post :approve_quote
          post :reject_quote
          post :complete
          post :deliver
          post :cancel
        end
      end

      # Public order tracking — the ONLY route without JWT. See
      # TrackingController for what it deliberately withholds and why.
      # The constraint keeps the route from swallowing anything but an order
      # number, since the segment would otherwise eat dots and slashes.
      get "tracking/:number", to: "tracking#show", as: :tracking,
                              constraints: { number: /OS-\d+/i }

      # Administrative indicator: average execution time.
      get "indicators/average_execution_time", to: "indicators#average_execution_time"
    end
  end
end
