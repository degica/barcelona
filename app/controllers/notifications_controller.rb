class NotificationsController < ApplicationController
  before_action :load_district
  before_action :load_notification, except: [:index, :create]
  before_action :authorize_notification
  after_action :update_stack, only: [:create, :update, :destroy]

  def index
    notifications = @district.notifications
    render json: notifications
  end

  def create
    notification = @district.notifications.create!(permitted_params)
    render json: notification, status: 201
  end

  def update
    @notification.update!(permitted_params)
    render json: @notification
  end

  def show
    render json: @notification
  end

  def destroy
    @notification.destroy!
    head 204
  end

  private

  def permitted_params
    params.permit(
      :target,
      :endpoint
    )
  end

  def update_stack
    @district.update_notification_stack
  end

  def load_notification
    @notification = @district.notifications.find(params[:id])
    authorize @notification
  end

  def authorize_notification
    authorize(@notification || Notification)
  end

  def load_district
    @district = District.find_by!(name: params[:district_id])
  end
end
