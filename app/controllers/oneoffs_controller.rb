class OneoffsController < ApplicationController
  before_action :load_heritage, only: [:create]
  before_action :load_oneoff, except: [:index, :create]
  before_action :authorize_heritage

  def show
    render json: @oneoff
  end

  def create
    interactive = !!params[:interactive]
    @oneoff = @heritage.oneoffs.create!(create_params)
    @oneoff.run!(sync: !!params[:sync], interactive: interactive, started_by: "barcelona/#{current_user.name}")
    json = if interactive
             certificate = @heritage.district.ca_sign_public_key(
               current_user,
               identity: "#{current_user.name}@#{@heritage.name}",
               force_command: '/etc/ssh/exec-interactive-oneoff.sh'
             )
             {oneoff: OneoffSerializer.new(@oneoff), certificate: certificate}
           else
             {oneoff: OneoffSerializer.new(@oneoff)}
           end

    render json: json
  end

  private

  def create_params
    params.permit(
      :command,
      :memory,
      :user
    )
  end

  def load_heritage
    @heritage = Heritage.find_by!(name: params[:heritage_id])
  end

  def load_oneoff
    @oneoff = Oneoff.find_by!(id: params[:id])
  end
end
