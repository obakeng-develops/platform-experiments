Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "dashboard#show"

  resources :bibes, only: %i[create destroy show] do
    post "services/:service_id/deploy", to: "bibe_services#deploy", as: :deploy_service
    post "services/:service_id/unpin", to: "bibe_services#unpin", as: :unpin_service
    post "reconcile", to: "bibes#reconcile", on: :member
  end

  post "environments/:environment_id/deploy/:service_id", to: "environments#deploy", as: :deploy_parent_service
end
