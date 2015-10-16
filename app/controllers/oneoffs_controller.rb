class OneoffsController < ApplicationController
  before_action :load_heritage, only: [:create]
  before_action :load_oneoff, except: [:index, :create]

  def show
    render json: @oneoff
  end

  def create
    @oneoff = @heritage.oneoffs.create!(create_params)
    sync = params[:sync] || false
    @oneoff.run!(sync: sync)
    render json: @oneoff
  end

  private

  def create_params
    params.permit(
      :command
    ).tap do |whitelisted|
      whitelisted[:env_vars] = params[:env_vars]
    end
  end

  def load_heritage
    @heritage = Heritage.find_by!(name: params[:heritage_id])
  end

  def load_oneoff
    @oneoff = Oneoff.find_by!(id: params[:id])
  end
end
