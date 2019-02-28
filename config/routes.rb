Rails.application.routes.draw do
  scope :v1 do
    resources :districts, except: [:new, :edit] do
      member do
        post :apply_stack
        post :sign_public_key
      end

      resources :plugins, only: [:index, :show, :destroy]
      put "/plugins/:id", to: "plugins#put"

      resources :heritages, shallow: true, except: [:new, :edit] do
        post   :env_vars, on: :member, to: "heritages#set_env_vars"
        delete :env_vars, on: :member, to: "heritages#delete_env_vars"

        post "/trigger/:token", to: "heritages#trigger"
        resources :oneoffs, only: [:show, :create]

        get "/releases", to: "releases#index"
        get "/releases/:version", to: "releases#show"
        post "/releases/:version/rollback", to: "releases#rollback"
      end

      resources :endpoints, except: [:new, :edit]
      resources :notifications, except: [:new, :edit]
    end

    resources :users, only: [:index, :show, :update]
    resources :review_groups do
      resources :review_apps, path: "/apps"
      post "/apps/trigger/:token", to: "review_apps#trigger"
    end

    post "/login", to: "users#login"
    patch "/user", to: "users#update"
    get "/user", to: "users#show"
  end

  get "/health_check", to: "health_check#index"
end
