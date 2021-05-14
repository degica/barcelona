class HeritagesController < ApplicationController
  before_action :load_district, only:   [:index, :create]
  before_action :load_heritage, except: [:index, :create, :trigger]
  before_action :load_district_by_param, only: [:update, :trigger]
  skip_before_action :authenticate, only: [:trigger]

  def index
    render json: @district.heritages
  end

  def show
    render json: @heritage
  end

  def create
    if Heritage.find_by(name: params[:name]).present?
      raise ExceptionHandler::InternalServerError.new("heritage name is already used ")
    end

    @heritage = BuildHeritage.new(permitted_params, district: @district).execute
    @heritage.save_and_deploy!(without_before_deploy: true, description: "Create")
    render json: @heritage
  end

  def update
    @heritage = BuildHeritage.new(permitted_params, district: @district).execute
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

  def update_service_scale
    service.desired_container_count = desired_container_count
    service.save!
    @heritage.save_and_deploy!(without_before_deploy: true,
                               description: "Change service scale #{service.name} to #{desired_container_count}")

    render json: @heritage
  end

  PERMITTED_PARAMS = [
    [
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
        :web_container_port,
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
        :value_from,
        :ssm_path
      ]
    ]
  ].freeze

  def permitted_params
    params.permit(PERMITTED_PARAMS).tap do |whitelisted|
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

  def load_district_by_param
    return if params[:district].blank?

    @district = District.find_by!(name: params[:district])
    if @heritage.district.name != @district.name
      raise ExceptionHandler::InternalServerError.new("The heritage #{@heritage.name} does not belong to district #{@district.name}")
    end
  end

  private

  def service
    @service ||= @heritage.services.find_by!(name: params.require(:service_name))
  end

  def desired_container_count
    params.require(:desired_container_count).to_i
  end
end
