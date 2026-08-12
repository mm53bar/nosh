Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "recipes#index"

  resources :recipes do
    member do
      post :made  # mark last_made_on = today
      post :image # fetch-by-URL image attach (raw upload just posts :image to create/update)
    end
    collection do
      post :import # create from a source URL's schema.org/Recipe JSON-LD
    end
  end

  resources :techniques
  resources :equipment, only: [ :index, :update ]

  resources :meal_plan_entries, only: [ :index, :create, :destroy ]

  resource :shopping_list, only: [ :show, :destroy ] do
    post :generate
  end
  resources :shopping_list_items, only: [ :update ] do
    collection { patch :bulk_update }
  end

  # The kitchen wall screen (a Home Assistant dashboard framing nosh on an Echo
  # Show). Read-mostly and self-contained — deliberately not the main /recipes
  # UI, whose type scale and edit/import affordances are wrong at counter
  # distance. See docs/adr/20260812-framed-by-home-assistant.md.
  namespace :kitchen do
    root "meals#index"
    resources :recipes, only: [ :show ] do
      member { post :made }
    end
  end

  get "/stats", to: "stats#show"
end
