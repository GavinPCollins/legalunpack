Rails.application.routes.draw do
  # devise authentication routes
  devise_for :users
  root to: "packages#new"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  # 7 CRUD routes for packages
  resources :packages do
    resources :chatbot_sessions, only: [:index, :create]
    post :analyze, on: :member
    get :analysis, on: :member
  end
  #   resources :clauses, only: [:index, :show] # Clauses nested inside packages .. create & edit are an AI finction
  #   resources :chats, only: [:show, :create] do # Chats nested inside packages
  #     resources :messages, only: [:create] # messages nested inside chats
  #   end
  # end

  # CODEX add document updates
  resources :doc_files, only: [:show, :create, :destroy] do
    get :summary, on: :member
    get :flags, on: :member
    get :dismissed_flags, on: :member
    post :archive, on: :member
    post :replace, on: :member
    get :summary_search, on: :collection
  end
  resources :flags, only: [:update]
  resources :legal_sources, only: [:index, :new, :create, :destroy] do
    post :autofill, on: :collection
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
