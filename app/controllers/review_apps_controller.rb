class ReviewAppsController < ApplicationController
  def create
    district = District.find_by(name: params[:district])
    reviewapp = nil
    ReviewApp.transaction do
      subject = params[:subject] || params[:template][:image_tag]
      reviewapp = ReviewApp.find_or_create_by(group: params[:group],
                                              base_domain: params[:base_domain],
                                              subject: subject)
      reviewapp.base_domain = params[:base_domain]
      reviewapp.retention_hours = params[:retention_hours] || 6
      reviewapp.create_heritage(params[:template], district)
      reviewapp.save!
    end

    render json: reviewapp
  end

  def index
    reviewapps = ReviewApp.where(group: params[:group])
    render json: reviewapps
  end

  def delete
    ReviewApp.find_by(group: params[:group], subject: params[:subject]).destroy!
    head 204
  end
end
