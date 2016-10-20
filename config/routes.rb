Rails.application.routes.draw do
  scope :v1 do
    resources :districts, except: [:new, :edit] do
      member do
        post :apply_stack
        post :sign_public_key
      end

      resources :plugins, except: [:new, :edit]

      resources :heritages, shallow: true, except: [:new, :edit] do
        post   :env_vars, on: :member, to: "heritages#set_env_vars"
        delete :env_vars, on: :member, to: "heritages#delete_env_vars"

        post "/services/:service_id/scale", to: "services#scale"
        post "/trigger/:token", to: "heritages#trigger"
        resources :oneoffs, only: [:show, :create]

        get "/releases", to: "releases#index"
        get "/releases/:version", to: "releases#show"
        post "/releases/:version/rollback", to: "releases#rollback"
      end
    end

    resources :users, only: [:index, :show, :update]

    post "/login", to: "users#login"
    patch "/user", to: "users#update"
    get "/user", to: "users#show"
  end
end
