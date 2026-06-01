Rails.application.routes.draw do
  # devise authentication routes
  devise_for :users
  root to: "pages#home"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  # 7 CRUD routes for documents
  resources :documents do # do opens block for nested routes
    resources :clauses, only: [:index, :show] # Clauses nested inside documents .. create & edit are an AI finction
    resources :chats, only: [:show, :create] do # Chats nested inside documents
      resources :messages, only: [:create] # messages nested inside chats
    end
  end

  # standalone resource for file uploads ... no editing of raw files.
  resources :doc_files, only: [:create, :destroy]

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
