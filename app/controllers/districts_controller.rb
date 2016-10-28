class DistrictsController < ApplicationController
  before_action :load_district, except: [:index, :create]

  def index
    @districts = policy_scope(District)
    render json: @districts.all
  end

  def show
    authorize @district
    render json: @district
  end

  def create
    @district = District.new(create_params)
    authorize @district
    ApplyDistrict.new(@district).create!
    render json: @district, status: 201
  end

  def update
    authorize @district
    @district.update!(update_params)
    render json: @district
  end

  def apply_stack
    authorize @district
    # Make sure the related resources are in-sync
    @district.save!
    ApplyDistrict.new(@district).apply
    render status: 202, nothing: true
  end

  def destroy
    authorize @district
    ApplyDistrict.new(@district).destroy!
    render status: 204, nothing: true
  end

  def sign_public_key
    authorize @district
    certificate = @district.ca_sign_public_key(current_user)
    json = {district: DistrictSerializer.new(@district), certificate: certificate}
    render json: json
  end

  private

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
end
