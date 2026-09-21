Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :utilities, only: :create
  resources :meters, only: %i[create show]
  resources :top_ups, only: %i[create show]
  resources :meter_readings, only: %i[create show]
end
