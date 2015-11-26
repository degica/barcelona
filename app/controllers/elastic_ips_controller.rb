class ElasticIpsController < ApplicationController
  before_action :load_district

  def index
    eips = @district.elastic_ips
    render json: eips
  end

  def create
    eip = @district.elastic_ips.create!(allocation_id: params[:allocation_id])
    render json: eip
  end

  def destroy
    alloc_id = params.require :allocation_id
    eip = @district.elastic_ips.find_by(allocation_id: alloc_id)
    eip.destroy!
    render status: 204, nothing: true
  end

  def load_district
    @district = District.find_by!(name: params[:district_id])
    if request.method == "GET"
      authorize @district, :show?
    else
      authorize @district, :update?
    end
  end
end
