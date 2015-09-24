class OneoffsController < ApplicationController
  before_action :load_heritage, only: [:create]
  before_action :load_oneoff, except: [:index, :create]

  def show
    render json: @oneoff
  end

  def create
    @oneoff = @heritage.oneoffs.create(create_params)
    @oneoff.run!
    render json: @oneoff
  end

  private

  def create_params
    params.permit [
      :env_vars,
      command: []
    ]
  end

  def load_heritage
    @heritage = Heritage.find_by!(name: params[:heritage_id])
  end

  def load_oneoff
    @oneoff = Oneoff.find_by!(id: params[:id])
  end
end
