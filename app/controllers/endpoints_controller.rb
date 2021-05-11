class EndpointsController < ApplicationController
  before_action :load_district
  before_action :load_endpoint, except: %i[index create]

  def index
    endpoints = @district.endpoints
    render json: endpoints, fields: %i[name public ssl_policy certificate_id]
  end

  def create
    endpoint = @district.endpoints.create!(create_params)
    render json: endpoint
  end

  def update
    @endpoint.update!(update_params)
    render json: @endpoint
  end

  def show
    render json: @endpoint
  end

  def destroy
    @endpoint.destroy!
    head 204
  end

  private

  def create_params
    params[:name] = name_prefix + params[:name]

    params.permit(
      :name,
      :public,
      :certificate_id,
      :ssl_policy
    )
  end

  def update_params
    params.permit(
      :certificate_id,
      :ssl_policy
    )
  end

  def load_endpoint
    @endpoint = @district.endpoints.find_by(name: params[:id])
    unless @endpoint.present?
      @endpoint = @district.endpoints.find_by!(name: name_prefix + params[:id])
    end
    @endpoint
  end

  def load_district
    @district = District.find_by!(name: params[:district_id])
  end

  def name_prefix
    "#{@district.name}-"
  end
end
