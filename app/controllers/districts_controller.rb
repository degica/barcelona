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
    @district = District.create!(create_params)
    render json: @district
  end

  def update
    @district.update!(update_params)
    render json: @district
  end

  def launch_instances
    count = params.require(:count)
    instance_type = params[:instance_type] || 't2.micro'
    section = params[:section] || :private
    @district.launch_instances(count: count, instance_type: instance_type, section: section)
    render status: 204, nothing: true
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
      :vpc_id,
      :public_elb_security_group,
      :private_elb_security_group,
      :instance_security_group,
      :ecs_service_role,
      :ecs_instance_role,
      :private_hosted_zone_id,
      :s3_bucket_name,
      :logentries_token,
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
