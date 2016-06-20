class AppsController < ApplicationController
  before_action :load_district, only:   [:index, :create]
  before_action :load_app, except: [:index, :create, :trigger]
  skip_before_action :authenticate, only: [:trigger]

  def index
    render json: @district.apps
  end

  def show
    render json: @app
  end

  def create
    @app = BuildApp.new(permitted_params, district: @district).execute
    @app.save_and_deploy!(without_before_deploy: true, description: "Create")
    render json: @app
  end

  def update
    @app = BuildApp.new(permitted_params).execute
    @app.save_and_deploy!(without_before_deploy: false,
                               description: "Update to #{@app.image_path}")
    render json: @app
  end

  def destroy
    @app.destroy!
    render status: 204, nothing: true
  end

  def trigger
    @app = App.find_by!(name: params[:app_id])
    if params[:image_name].present? && @app.image_name != params[:image_name]
      raise ExceptionHandler::Forbidden
    end

    params[:id] = params.delete :app_id
    if Rack::Utils.secure_compare(params[:token], @app.token)
      update
    else
      raise ExceptionHandler::NotFound
    end
  end

  def set_env_vars
    env_vars = params[:env_vars]
    env_vars.each do |k, v|
      env = @app.env_vars.find_or_create_by(key: k)
      env.value = v
      env.save!
    end
    @app.save_and_deploy!(without_before_deploy: true,
                          description: "Set environments #{env_vars.keys.join(', ')}")

    render json: @app
  end

  def delete_env_vars
    env_keys = params[:env_keys]
    env_keys.each do |k|
      @app.env_vars.find_by(key: k).destroy!
    end
    @app.save_and_deploy!(without_before_deploy: true,
                               description: "Unset environments #{env_keys.join(', ')}")

    render json: @app
  end

  def permitted_params
    params.permit([
      :id,
      :name,
      :image_name,
      :image_tag,
      :slack_url,
      :before_deploy,
      services: [
        :name,
        :cpu,
        :memory,
        :command,
        :reverse_proxy_image,
        :public,
        :service_type,
        :force_ssl,
        {
          port_mappings: [
            :lb_port,
            :host_port,
            :container_port,
            :protocol,
            :enable_proxy_protocol
          ],
          hosts: [
            :hostname,
            :ssl_cert_path,
            :ssl_key_path
          ]
        }
      ]
    ]).tap do |whitelisted|
      whitelisted[:env_vars] = params[:env_vars] if params[:env_vars].present?
      if params[:services].present?
        params[:services].each_with_index do |s, i|
          whitelisted[:services][i][:health_check] = s[:health_check] if s.key?(:health_check)
        end
      end
    end
  end

  def load_app
    @app = App.find_by!(name: params[:id])
  end

  def load_district
    @district = District.find_by!(name: params[:district_id])
  end
end
