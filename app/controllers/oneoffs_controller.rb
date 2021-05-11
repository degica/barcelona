class OneoffsController < ApplicationController
  before_action :load_heritage, only: [:create]
  before_action :load_oneoff, except: %i[index create]

  def show
    render json: @oneoff
  end

  def create
    interactive = !!params[:interactive]
    @oneoff = @heritage.oneoffs.create!(create_params)
    @oneoff.run!(sync: !!params[:sync],
                 interactive: interactive,
                 started_by: "barcelona/#{current_user.name}",
                 env_vars: env_var_params)
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

  def env_var_params
    return {} if params[:env_vars].nil?

    raise ExceptionHandler::BadRequest.new("env_vars should be a hash") unless params[:env_vars].is_a? ActionController::Parameters

    params[:env_vars].each do |key, value|
      unless key.is_a? String
        raise ExceptionHandler::BadRequest.new("Keys in env_vars should be strings")
      end
      unless value.is_a? String
        raise ExceptionHandler::BadRequest.new("Values in env_vars should be strings")
      end
    end

    params[:env_vars].permit(params[:env_vars].keys)
  end

  def load_heritage
    @heritage = Heritage.find_by!(name: params[:heritage_id])
  end

  def load_oneoff
    @oneoff = Oneoff.find_by!(id: params[:id])
  end
end
