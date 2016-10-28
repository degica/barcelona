class OneoffsController < ApplicationController
  before_action :load_heritage, only: [:create]
  before_action :load_oneoff, except: [:index, :create]

  def show
    authorize @oneoff
    render json: @oneoff
  end

  def create
    @oneoff = @heritage.oneoffs.new(create_params)
    authorize @oneoff
    @oneoff.save!

    interactive = !!params[:interactive]
    @oneoff.run!(sync: !!params[:sync], interactive: interactive)
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
      :command
    )
  end

  def load_heritage
    @heritage = Heritage.find_by!(name: params[:heritage_id])
  end

  def load_oneoff
    @oneoff = Oneoff.find_by!(id: params[:id])
  end
end
