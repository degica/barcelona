class PluginsController < ApplicationController
  before_action :load_district
  before_action :load_plugin, except: [:index, :create]

  def create
    name = params.require :name
    @plugin = @district.plugins.create!(name: name,
                                        plugin_attributes: params[:attributes])
    render json: @plugin
  end

  def index
    @plugins = @district.plugins
    render json: @plugins
  end

  def show
    render json: @plugin
  end

  def update
    attributes = params.require :attributes
    @plugin.update!(plugin_attributes: attributes)
    render json: @plugin
  end

  def destroy
    @plugin.destroy!
    render status: 204, nothing: true
  end

  private

  def load_district
    @district = District.find_by!(name: params[:district_id])
  end

  def load_plugin
    @plugin = @district.plugins.find_by!(name: params[:id])
  end
end
