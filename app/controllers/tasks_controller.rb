class TasksController < ApplicationController
  def create
    scale = params.require(:scale)
    heritage = Heritage.select(:id).find_by(name: params[:heritage_id])
    service = Service.find_by(heritage: heritage, name: params[:id])
    service.scale(scale)

    render json: service
  end
end
