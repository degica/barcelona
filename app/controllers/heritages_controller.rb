class HeritagesController < ApplicationController
  before_action :load_district,  only:   [:index, :create]
  before_action :load_heritage, except: [:index, :create]

  def index
    render json: @district.heritages
  end

  def show
    render json: @heritage
  end

  def create
    @heritage = @district.heritages.create!(create_params)
    render json: @heritage
  end

  def update
    @heritage.update!(update_params)
    render json: @heritage
  end

  def destroy
    @heritage.destroy!
    render status: 204, nothing: true
  end

  def set_env_vars
    env_vars = params[:env_vars]
    env_vars.each do |k, v|
      env = @heritage.env_vars.find_or_create_by(key: k)
      env.value = v
      env.save!
    end
    @heritage.save!

    render json: @heritage
  end

  def delete_env_vars
    env_vars = params[:env_keys]
    env_vars.each do |k|
      @heritage.env_vars.find_by(key: k).destroy!
    end
    @heritage.save!

    render json: @heritage
  end

  def update_params
    permitted = create_params
    permitted.delete :district_name
    permitted.delete :name

    map = Hash[@heritage.services.pluck(:name, :id)]
    if permitted[:services].present?
      permitted[:services_attributes].each do |service|
        service.delete :port_mappings_attributes # Currently updating port mapping is not supported
        name = service.delete :name
        service[:id] = map[name]
      end
    end
    permitted
  end

  def create_params
    permitted = params.permit [
      :name,
      :container_name,
      :container_tag,
      services: [
        :name,
        :cpu,
        :memory,
        :public,
        {
          port_mappings: [:lb_port, :container_port]
        }
      ]
    ]
    if permitted[:services].present?
      permitted[:services_attributes] = permitted.delete(:services)
      permitted[:services_attributes].each do |service|
        service[:port_mappings_attributes] = service.delete(:port_mappings) if service[:port_mappings].present?
      end
    end
    permitted
  end

  def load_heritage
    @heritage = Heritage.find_by(name: params[:id])
  end

  def load_district
    @district = District.find_by!(name: params[:district_id])
  end
end
