Rails.application.routes.draw do
  resources :districts, except: [:new, :edit] do
    member do
      post :launch_instances
    end

    resources :heritages, shallow: true, except: [:new, :edit] do
      post   :env_vars, on: :member, to: "heritages#set_env_vars"
      delete :env_vars, on: :member, to: "heritages#delete_env_vars"

      post "/services/:service_id/scale", to: "services#scale"
      resources :oneoffs, only: [:show, :create]
    end
  end

  post "/login", to: "users#login"
  patch "/user", to: "users#update"
  get "/user", to: "users#show"
end
