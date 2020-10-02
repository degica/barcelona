class HealthCheckController < ApplicationController
  skip_before_action :authenticate
  skip_before_action :authorize_action

  def index
    head 200
  end
end
