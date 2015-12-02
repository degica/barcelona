class HeritagesController < ApplicationController
  before_action :load_district,  only:   [:index, :create]
  before_action :load_heritage, except: [:index, :create, :trigger]
  skip_before_action :authenticate, only: [:trigger]

  def index
    render json: @district.heritages
  end

  def show
    render json: @heritage
  end

  def create
    @heritage = BuildHeritage.new(permitted_params, district: @district).execute
    @heritage.save_and_deploy!(without_before_deploy: true)
    render json: @heritage
  end

  def update
    @heritage = BuildHeritage.new(permitted_params).execute
    @heritage.save_and_deploy!(without_before_deploy: false)
    render json: @heritage
  end

  def destroy
    @heritage.destroy!
    render status: 204, nothing: true
  end

  def trigger
    @heritage = Heritage.find_by!(name: params[:heritage_id])
    params[:id] = params.delete :heritage_id
    if Rack::Utils.secure_compare(params[:token], @heritage.token)
      update
    else
      raise ExceptionHandler::NotFound
    end
  end

  def set_env_vars
    env_vars = params[:env_vars]
    env_vars.each do |k, v|
      env = @heritage.env_vars.find_or_create_by(key: k)
      env.value = v
      env.save!
    end
    @heritage.save_and_deploy!(without_before_deploy: true)

    render json: @heritage
  end

  def delete_env_vars
    env_keys = params[:env_keys]
    env_keys.each do |k|
      @heritage.env_vars.find_by(key: k).destroy!
    end
    @heritage.save_and_deploy!(without_before_deploy: true)

    render json: @heritage
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
    end
  end

  def load_heritage
    @heritage = Heritage.find_by!(name: params[:id])
  end

  def load_district
    @district = District.find_by!(name: params[:district_id])
  end
end
