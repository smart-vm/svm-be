Rails.application.routes.draw do
  root "dashboards#index"

  resources :machines, only: [ :index, :new, :create, :edit, :update ]
  resources :inventories, only: [ :index ]
  resources :transactions, only: [ :index ]

  namespace :api do
    namespace :v1 do
      post 'payments/webhook', to: 'payments#webhook'
    end
  end

  mount ActionCable.server => '/cable'
end