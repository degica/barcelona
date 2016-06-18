class ReleasesController < ApplicationController
  before_action :load_app
  before_action :load_release, only: [:show, :rollback]

  def show
    render json: @release
  end

  def index
    render json: @app.releases.first(10)
  end

  def rollback
    new_release = @release.rollback
    render json: new_release
  end

  private

  def load_app
    @app = App.find_by!(name: params[:app_id])
  end

  def load_release
    @release = @app.releases.find_by!(version: params[:version])
  end
end
