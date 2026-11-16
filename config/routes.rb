Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "leads#index"
  resources :leads, only: %i[index show] do
    resource :outreach, only: %i[create destroy], controller: "outreaches" do
      patch :accepted
      patch :variant
      patch :reply
      post :message_sent
      delete :message_sent, action: :undo_message
    end
  end
  resources :messages, only: :update
  resources :exports, only: %i[index create show] do
    get :download, on: :member
    post :import_replies, on: :collection
  end
  get "dashboard", to: "dashboard#show"
  resource :spend, only: :show, controller: "spend" do
    patch :cap, on: :member
  end

  get "results", to: "results#show"
  post "results/defaults", to: "results#approve_default", as: :results_defaults
  delete "results/defaults", to: "results#revoke_default"
  post "results/examples/:send_id", to: "results#approve_example", as: :results_example
  delete "results/examples/:send_id", to: "results#revoke_example"
end
