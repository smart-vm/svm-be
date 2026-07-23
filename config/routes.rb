Rails.application.routes.draw do
  root "dashboards#index"

  resources :machines, only: [ :index ]
  resources :inventories, only: [ :index ]

  namespace :api do
    namespace :v1 do
      # Gateway Webhook Route
      post 'payments/webhook', to: 'payments#webhook'
    end
  end

  # Mount the live ActionCable server websocket route
  mount ActionCable.server => '/cable'
end