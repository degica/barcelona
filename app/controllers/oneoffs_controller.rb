class OneoffsController < ApplicationController
  before_action :load_app, only: [:create]
  before_action :load_oneoff, except: [:index, :create]

  def show
    render json: @oneoff
  end

  def create
    @oneoff = @app.oneoffs.create!(create_params)
    sync = params[:sync] || false
    @oneoff.run!(sync: sync)
    render json: @oneoff
  end

  private

  def create_params
    params.permit(
      :command,
      :image_tag
    ).tap do |whitelisted|
      whitelisted[:env_vars] = params[:env_vars]
    end
  end

  def load_app
    @app = App.find_by!(name: params[:app_id])
  end

  def load_oneoff
    @oneoff = Oneoff.find_by!(id: params[:id])
  end
end
