class SsmParametersController < ApplicationController
  before_action :load_district, only: [:create, :destroy]

  def create
    ssm_parameter = SsmParameters.new(@district, params[:name])
    ssm_parameter.put_parameter(params[:value], params[:type])

    head 200
  end

  def destroy
    ssm_parameter = SsmParameters.new(@district, params[:id])
    response = ssm_parameter.delete_parameter

    render json: {
      deleted_parameters: response.deleted_parameters,
      invalid_parameters: response.invalid_parameters
    }
  end

  private

  def load_district
    @district = District.find_by!(name: params[:district_id])
  end
end
