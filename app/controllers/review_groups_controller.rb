class ReviewGroupsController < ApplicationController
  def create
    authorize_resource ReviewGroup
    endpoint = Endpoint.find_by!(name: params[:endpoint])
    group = ReviewGroup.create!(
      name: params[:name],
      base_domain: params[:base_domain],
      endpoint: endpoint
    )
    render json: group
  end

  def show
    group = ReviewGroup.find_by!(name: params[:id])
    authorize_resource group
    render json: group
  end

  def index
    groups = ReviewGroup.all
    render json: groups
  end

  def destroy
    group = ReviewGroup.find_by!(name: params[:id])
    authorize_resource group
    group.destroy!

    head 204
  end
end
