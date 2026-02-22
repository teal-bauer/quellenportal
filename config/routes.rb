Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', :as => :rails_health_check

  # Defines the root path route ("/")
  root 'search#index'

  get 'legal-notice' => 'pages#legal_notice'
  get 'search-help' => 'pages#search_help', as: :search_help

  get 'browse/fonds' => 'search#index', tab: 'fonds', as: :browse_fonds
  get 'browse/origins' => 'search#index', tab: 'origins', as: :browse_origins
  get 'browse/dates' => 'search#index', tab: 'dates', as: :browse_dates

  resources :archive_files, only: [:show]
  resources :archive_nodes, only: [:show]

  namespace :admin do
    get "status" => "meilisearch#index"
  end
end
