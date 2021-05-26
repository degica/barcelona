class SsmParametersController < ApplicationController
  before_action :load_district, only: [:create]

  def create
    ssm_parameter = SsmParameters.new(@district, params[:name])
    ssm_parameter.put_parameter(params[:value])

    head 200
  end

  private

  def load_district
    @district = District.find_by!(name: params[:district_id])
  end
end
