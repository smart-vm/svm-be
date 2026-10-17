Rails.application.routes.draw do
  devise_for :users
  root "dashboards#index"

  resources :machines, only: [ :index, :new, :create, :edit, :update, :show ]
  resources :inventories, only: [ :index, :new, :create, :edit, :update ]
  resources :transactions, only: [ :index ] do
    member { patch :resolve }
  end
  resources :slots, only: [ :new, :create, :edit, :update ]
  resources :advertisements, except: [ :show ]

  namespace :api do
    namespace :v1 do
      post "payments/webhook", to: "payments#webhook"

      namespace :kiosk do
        resource :catalog, only: :show
        resources :ads, only: :index
        resources :transactions, only: [ :create, :show ], param: :uuid do
          member do
            post :cancel
            post :claim
            post :vend_result
          end
        end
      end
    end
  end

  # Local stand-in for the RafflesPay hosted checkout (PAYMENT_GATEWAY=mock only).
  get "mock_gateway/checkouts/:uuid", to: "mock_gateway#show", as: :mock_gateway_checkout
  post "mock_gateway/checkouts/:uuid/complete", to: "mock_gateway#complete", as: :mock_gateway_checkout_complete

  # Web app manifest (icons + name when the back office is added to a home screen).
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  mount ActionCable.server => "/cable"
end
