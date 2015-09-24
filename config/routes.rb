Rails.application.routes.draw do
  resources :districts, except: [:new, :edit], shallow: true do
    resources :heritages, except: [:new, :edit] do
      post   :run_task, on: :member
      post   :env_vars, on: :member, to: "heritages#set_env_vars"
      delete :env_vars, on: :member, to: "heritages#delete_env_vars"

      post "/services/:service_id/scale", to: "services#scale"
    end
  end
end
