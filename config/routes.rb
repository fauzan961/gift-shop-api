Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :admin do
    resource :session, only: %i[ new create destroy ]
    resources :categories, only: %i[ index show new create edit update destroy ]
    resources :occasions, only: %i[ index show new create edit update destroy ]
    resources :products, only: %i[ index show new create edit update destroy ]

    root to: "categories#index"
  end

  # Defines the root path route ("/")
  # root "posts#index"

  scope path: "api/v1" do
    resources :categories, only: :index
    resources :occasions, only: :index
    resources :products, only: [ :index, :show ], param: :slug do
      get :related, on: :member
      resources :reviews, only: :index
      resource :review, only: [ :show, :create, :update, :destroy ]
    end

    post "auth/code", to: "auth_codes#create", as: :auth_code
    post "auth/verify", to: "auth_sessions#create", as: :auth_verify
    delete "auth/session", to: "auth_sessions#destroy", as: :auth_session

    resource :profile, only: [ :show, :update ]
    resources :addresses, only: [ :index, :create, :update, :destroy ]
    resources :favorites, only: [ :index, :create, :destroy ], param: :slug

    post "cart/check", to: "carts#check", as: :cart_check
    resources :orders, only: [ :index, :show, :create ], param: :number
  end
end
