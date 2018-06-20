class SecretsController < ApplicationController
  before_action :load_district

  def create
    secret = TransitSecret.new(@district)
    plaintext = Base64.decode64(params.require(:plaintext))
    enc = secret.create(plaintext)

    render json: {type: "transit", encrypted_value: enc}
  end

  def load_district
    @district = District.find_by!(name: params[:district_id])
  end
end
