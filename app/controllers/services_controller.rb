class ServicesController < ApplicationController
  def scale
    scale = params.require(:scale)
    app = App.select(:id).find_by(name: params[:app_id])
    service = Service.find_by(app: app, name: params[:service_id])
    service.scale(scale)

    render json: service
  end
end
