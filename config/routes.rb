Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # API routes
  namespace :api do
    namespace :v1 do
      post "projects/:project_key/environments/:environment_key/checks", to: "drift_checks#create", as: :environment_checks
    end
  end

  # Dashboard routes
  root "dashboard#index"
  get "projects/:key", to: "projects#show", as: :project
  get "projects/:project_key/environments/:key", to: "environments#show", as: :project_environment
end
