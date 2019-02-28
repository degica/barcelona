class HeritagesController < ApplicationController
  before_action :load_district, only:   [:index, :create]
  before_action :load_heritage, except: [:index, :create, :trigger]
  skip_before_action :authenticate, only: [:trigger]

  # Declarative environment doesn't work for scheduled tasks because scheduled tasks use CloudFormation
  # for creating task definitions and CF still does not support `ContainerDefinitions.Secrets` parameters.
  before_action :forbid_environment, only: [:create, :update, :trigger], unless: -> { Rails.env.test? }

  def index
    render json: @district.heritages
  end

  def show
    render json: @heritage
  end

  def create
    @heritage = BuildHeritage.new(permitted_params, district: @district).execute
    @heritage.save_and_deploy!(without_before_deploy: true, description: "Create")
    render json: @heritage
  end

  def update
    @heritage = BuildHeritage.new(permitted_params).execute
    @heritage.save_and_deploy!(without_before_deploy: false,
                               description: "Update to #{@heritage.image_path}")
    render json: @heritage
  end

  def destroy
    @heritage.destroy!
    head 204
  end

  def trigger
    @heritage = Heritage.find_by!(name: params[:heritage_id])
    if params[:image_name].present? && @heritage.image_name != params[:image_name]
      raise ExceptionHandler::Forbidden
    end

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
      env.secret = !!params[:secret]
      env.save!
    end
    @heritage.save_and_deploy!(without_before_deploy: true,
                               description: "Set environments #{env_vars.keys.join(', ')}")

    render json: @heritage
  end

  def delete_env_vars
    env_keys = params[:env_keys]
    env_keys.each do |k|
      @heritage.env_vars.find_by(key: k).destroy!
    end
    @heritage.save_and_deploy!(without_before_deploy: true,
                               description: "Unset environments #{env_keys.join(', ')}")

    render json: @heritage
  end

  def permitted_params
    params.permit([
      :id,
      :version,
      :name,
      :image_name,
      :image_tag,
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
          ],
          listeners: [
            :endpoint,
            :health_check_interval,
            :health_check_path,
            :rule_priority,
            rule_conditions: [
              :type,
              :value
            ]
          ]
        }
      ],
      scheduled_tasks: [
        :schedule,
        :command
      ],
      environment: [
        :name,
        :value,
        :value_from
      ]
    ]).tap do |whitelisted|
      if params[:services].present?
        params[:services].each_with_index do |s, i|
          whitelisted[:services][i][:health_check] = s[:health_check].permit(:protocol, :port) if s.key?(:health_check)
        end
      end
    end
  end

  def load_heritage
    @heritage = Heritage.find_by!(name: params[:id])
  end

  def load_district
    @district = District.find_by!(name: params[:district_id])
  end

  def forbid_environment
    raise "Specifying environment is not yet supproted for normal deployments" if params[:environment].present?
  end
end
