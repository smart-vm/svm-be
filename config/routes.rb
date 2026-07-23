Rails.application.routes.draw do
  get "dashboards/index", to: "dashboards#index", as: :dashboards_index
  root "dashboards#index"

  namespace :api do
    namespace :v1 do
      # Gateway Webhook Route
      post 'payments/webhook', to: 'payments#webhook'
    end
  end

  # Mount the live ActionCable server websocket route
  mount ActionCable.server => '/cable'
end