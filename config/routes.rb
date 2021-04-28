Rails.application.routes.draw do
  scope :v1 do
    resources :districts, except: [:new, :edit] do
      member do
        post :apply_stack
        post :sign_public_key
        get "/get_ssm_parameter/:name", to: "districts#get_ssm_parameter"
        post "/set_ssm_parameter/:name", to: "districts#set_ssm_parameter"
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

      resources :heritages, except: [:new, :edit] do
        post   :env_vars, on: :member, to: "heritages#set_env_vars"
        delete :env_vars, on: :member, to: "heritages#delete_env_vars"

        post "/trigger/:token", to: "heritages#trigger"
        resources :oneoffs, only: [:show, :create]

        get "/releases", to: "releases#index"
        get "/releases/:version", to: "releases#show"
        post "/releases/:version/rollback", to: "releases#rollback"

        post "/services/:service_name/count", on: :member, to: "heritages#update_service_scale"
      end

      resources :endpoints, except: [:new, :edit]
      resources :notifications, except: [:new, :edit]
    end

    resources :users, only: [:index, :show, :update]
    resources :review_groups do
      resources :review_apps, path: "/apps"
      post   "/ci/apps/:token", to: "review_apps#ci_create"
      delete "/ci/apps/:token/:id", to: "review_apps#ci_delete"
    end

    post "/login", to: "users#login"
    patch "/user", to: "users#update"
    get "/user", to: "users#show"
  end

  get "/health_check", to: "health_check#index"
end
