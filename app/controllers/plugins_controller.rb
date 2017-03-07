class PluginsController < ApplicationController
  before_action :load_district
  before_action :load_plugin, except: [:index, :put]

  def put
    @plugin = @district.plugins.find_or_initialize_by(name: params[:id])
    @plugin.plugin_attributes = params[:attributes]
    @plugin.save!

    render json: @plugin
  end

  def index
    @plugins = @district.plugins
    render json: @plugins
  end

  def show
    render json: @plugin
  end

  def destroy
    @plugin.destroy!
    render status: 204, nothing: true
    head 204
  end

  private

  def load_district
    @district = District.find_by!(name: params[:district_id])
  end

  def load_plugin
    @plugin = @district.plugins.find_by!(name: params[:id])
  end
end
