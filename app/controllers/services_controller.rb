class ServicesController < ApplicationController
  before_action :load_heritage
  before_action :load_service

  def scale
    authorize @service
    scale = params.require(:scale)
    @service.scale(scale)

    render json: @service
  end

  private

  def load_heritage
    @heritage = Heritage.find_by!(name: params[:heritage_id])
  end

  def load_service
    @service = Service.find_by!(heritage: @heritage, name: params[:service_id])
  end
end
