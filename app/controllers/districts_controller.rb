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
    render json: @district, status: 201
  end

  def update
    @district.update!(update_params)
    render json: @district
  end

  def launch_instances
    count = params.require(:count)
    instance_type = params[:instance_type] || 't2.micro'
    section = params[:section] || :private
    associate_eip = params[:associate_eip].to_s == "true"
    @district.launch_instances(count: count.to_i,
                               instance_type: instance_type,
                               section: section,
                               associate_eip: associate_eip)
    render status: 204, nothing: true
  end

  def terminate_instance
    section = params[:section] || :private
    arn = params[:container_instance_arn]
    @district.terminate_instance(container_instance_arn: arn, section: section)
    render status: 204, nothing: true
  end

  def apply_stack
    @district.apply_network_stack
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
      :bastion_key_pair,
      :nat_type,
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
