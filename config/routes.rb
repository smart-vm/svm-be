Rails.application.routes.draw do
  devise_for :users
  root "dashboards#index"

  resources :machines, only: [ :index, :new, :create, :edit, :update, :show ]
  resources :inventories, only: [ :index, :new, :create, :edit, :update ]
  resources :transactions, only: [ :index ]
  resources :slots, only: [ :new, :create, :edit, :update ]

  namespace :api do
    namespace :v1 do
      post 'payments/webhook', to: 'payments#webhook'
    end
  end

  mount ActionCable.server => '/cable'
end