class HealthCheckController < ApplicationController
  skip_before_action :authenticate

  def index
    head 200
  end
end
