class DistrictsController < ApplicationController
  before_action :load_district, except: [:index, :create]
  before_action :authorize_district

  def index
    @districts = District.all
    render json: @districts
  end

  def show
    render json: @district
  end

  def create
    @district = District.new(create_params)
    ApplyDistrict.new(@district).create!
    render json: @district, status: 201
  end

  def update
    @district.update!(update_params)
    render json: @district
  end

  def apply_stack
    # Make sure the related resources are in-sync
    @district.save!
    ApplyDistrict.new(@district).apply
    render status: 202, nothing: true
  end

  def destroy
    @district.destroy!
    render status: 204, nothing: true
  end

  def update_params
    permitted = create_params
    permitted.delete :name
    permitted
  end

  def create_params
    params.permit(
      :name,
      :region,
      :bastion_key_pair,
      :nat_type,
      :cluster_backend,
      :cluster_size,
      :cluster_instance_type,
      :aws_access_key_id,
      :aws_secret_access_key
    ).tap do |whitelisted|
      whitelisted[:dockercfg] = params[:dockercfg] if params[:dockercfg].present?
    end
  end

  def load_district
    @district = District.find_by!(name: params[:id])
  end

  def authorize_district
    if @district.present?
      authorize @district
    else
      authorize District
    end
  end
end
