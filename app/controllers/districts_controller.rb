class DistrictsController < ApplicationController
  before_action :load_district, except: [:index, :create]
  before_action :authorize_district

  def index
    @districts = District.all
    render json: @districts, fields: [:name, :region, :cluster_size, :cluster_instance_type, :stack_name, :aws_access_key_id, :aws_role]
  end

  def show
    render json: @district
  end

  def create
    cparams = create_params
    access_key_id = cparams.delete(:aws_access_key_id)
    secret_access_key = cparams.delete(:aws_secret_access_key)
    @district = District.new(cparams)

    ApplyDistrict.new(@district).create!(access_key_id, secret_access_key)

    render json: @district, status: 201
  end

  def update
    uparams = update_params
    @district.attributes = uparams
    access_key_id = uparams.delete(:aws_access_key_id)
    secret_access_key = uparams.delete(:aws_secret_access_key)
    ApplyDistrict.new(@district).update!(access_key_id, secret_access_key)

    render json: @district
  end

  def apply_stack
    # Make sure the related resources are in-sync
    @district.save!
    ApplyDistrict.new(@district).apply
    head 202
  end

  def destroy
    ApplyDistrict.new(@district).destroy!
    head 204
  end

  def sign_public_key
    certificate = @district.ca_sign_public_key(current_user)
    json = {district: DistrictSerializer.new(@district), certificate: certificate}
    render json: json
  end

  def get_ssm_parameter
    process_ssm = ProcessSsm.new(@district, params[:name])
    response = process_ssm.get_parameter

    render json: response.parameter.to_json

    rescue Aws::SSM::Errors::ParameterNotFound
      error_message = "The ssm_path #{process_ssm.ssm_path} does not exist in district #{@district.name}"
      render json: error_message.to_json, status: 400
  end

  def set_ssm_parameter
    process_ssm = ProcessSsm.new(@district, params[:name])
    process_ssm.put_parameter(params[:value], params[:type])

    head 200
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
      :nat_type,
      :cluster_size,
      :cluster_instance_type,
      :aws_access_key_id,
      :aws_secret_access_key
    ).tap do |whitelisted|
      whitelisted[:dockercfg] = params[:dockercfg].permit! if params[:dockercfg].present?
    end
  end

  def load_district
    @district = District.find_by!(name: params[:id])
  end

  def authorize_district
    if @district.present?
      authorize_resource @district
    else
      authorize_resource District
    end
  end
end
