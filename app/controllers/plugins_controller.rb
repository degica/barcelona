class PluginsController < ApplicationController
  before_action :load_district
  before_action :load_plugin, except: [:index, :create]

  def create
    name = params.require :name
    @plugin = @district.plugins.build(name: name,
                                        plugin_attributes: params[:attributes])
    authorize @plugin
    @plugin.save!
    render json: @plugin
  end

  def index
    @plugins = policy_scope(@district.plugins)
    render json: @plugins
  end

  def show
    authorize @plugin
    render json: @plugin
  end

  def update
    authorize @plugin
    attributes = params.require :attributes
    @plugin.update!(plugin_attributes: attributes)
    render json: @plugin
  end

  def destroy
    authorize @plugin
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
