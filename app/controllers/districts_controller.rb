class DistrictsController < ApplicationController
  before_action :load_district, except: [:index, :create]

  def index
    @districts = District.all
    render json: @districts
  end

  def show
    render json: @district
  end

  def create
    @district = District.create(create_params)
    render json: @district
  end

  def destroy
    @district.destroy!
    render status: 204, nothing: true
  end

  def create_params
    params.permit [
      :name,
      :vpc_id,
      :public_elb_security_group,
      :private_elb_security_group,
      :instance_security_group,
      :ecs_service_role,
      :ecs_instance_role
    ]
  end

  def load_district
    @district = District.find_by!(name: params[:id])
  end
end
