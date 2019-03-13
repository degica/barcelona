class ReviewAppsController < ApplicationController
  skip_before_action :authenticate, only: [:ci_create, :ci_delete]
  before_action :load_review_group

  def create
    reviewapp = @review_group.review_apps.find_or_initialize_by(subject: params[:subject])
    reviewapp.attributes = permitted_params
    authorize_resource reviewapp
    reviewapp.save!

    render json: reviewapp
  end

  def ci_create
    if Rack::Utils.secure_compare(params[:token], @review_group.token)
      create
    else
      raise ExceptionHandler::NotFound
    end
  end

  def index
    render json: @review_group.review_apps
  end

  def destroy
    review_app = @review_group.review_apps.find_by!(subject: params[:id])
    authorize_resource review_app
    review_app.destroy!

    head 204
  end

  def ci_delete
    if Rack::Utils.secure_compare(params[:token], @review_group.token)
      destroy
    else
      raise ExceptionHandler::NotFound
    end
  end

  private

  def load_review_group
    @review_group = ReviewGroup.find_by!(name: params[:review_group_id])
  end

  def permitted_params
    params.permit([
                    :subject,
                    :retention,
                    :image_name,
                    :image_tag,
                    :before_deploy,
                    environment: [
                      :name,
                      :value,
                      :ssm_path,
                      :value_from
                    ],
                    services: [
                      :name,
                      :service_type,
                      :cpu,
                      :memory,
                      :command,
                      :force_ssl
                    ]
                  ])
  end
end
