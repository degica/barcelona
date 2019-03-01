class ReviewAppsController < ApplicationController
  skip_before_action :authenticate, only: [:trigger]
  before_action :authorize_app, only: [:create, :trigger]

  def create
    group = ReviewGroup.find_by!(name: params[:review_group_id])
    reviewapp = group.review_apps.find_or_initialize_by(subject: params[:subject])
    reviewapp.attributes = {
      subject: params[:subject],
      retention_hours: 24,
      image_name: params[:image_name],
      image_tag: params[:image_tag],
      before_deploy: params[:before_deploy],
      environment: (params[:environment] || []).map { |e| e.permit!.to_h },
      service_params: (params[:service] || {}).permit!.to_h
    }
    reviewapp.save!

    render json: reviewapp
  end

  def trigger
    group = ReviewGroup.find_by!(name: params[:review_group_id])

    if Rack::Utils.secure_compare(params[:token], group.token)
      create
    else
      raise ExceptionHandler::NotFound
    end
  end

  def index
    group = ReviewGroup.find_by!(name: params[:review_group_id])
    render json: group.review_apps
  end

  def destroy
    group = ReviewGroup.find_by!(name: params[:review_group_id])
    review_app = group.review_apps.find_by!(subject: params[:id])
    authorize_resource review_app
    review_app.destroy!

    head 204
  end

  def authorize_app
    authorize_resource ReviewApp
  end
end
