Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "leads#index"
  resources :leads, only: %i[index show] do
    resource :contact, only: :create
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
  post "contact_research", to: "contact_research#create", as: :contact_research
  post "pipeline/fetch", to: "pipeline#fetch", as: :pipeline_fetch
  post "pipeline/score", to: "pipeline#score", as: :pipeline_score
  post "pipeline/draft", to: "pipeline#draft", as: :pipeline_draft
  post "pipeline/partner_draft", to: "pipeline#partner_draft", as: :pipeline_partner_draft
  get "partners", to: "partners#index"
  patch "partners/:id/sent", to: "partners#sent", as: :partner_sent
  patch "partners/:id/dismiss", to: "partners#dismiss", as: :partner_dismiss
  patch "partners/:id/restore", to: "partners#restore", as: :partner_restore
  get "imports", to: "imports#new", as: :new_import
  post "imports/accounts", to: "imports#accounts", as: :import_accounts
  post "imports/people", to: "imports#people", as: :import_people
  resource :spend, only: :show, controller: "spend" do
    patch :cap, on: :member
  end

  get "results", to: "results#show"
  post "results/defaults", to: "results#approve_default", as: :results_defaults
  delete "results/defaults", to: "results#revoke_default"
  post "results/examples/:send_id", to: "results#approve_example", as: :results_example
  delete "results/examples/:send_id", to: "results#revoke_example"
end
