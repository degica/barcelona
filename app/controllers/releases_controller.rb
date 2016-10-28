class ReleasesController < ApplicationController
  before_action :load_heritage
  before_action :load_release, only: [:show, :rollback]

  def show
    authorize @release
    render json: @release
  end

  def index
    releases = policy_scope(@heritage.releases)
    render json: releases.first(10)
  end

  def rollback
    authorize @release
    new_release = @release.rollback
    render json: new_release
  end

  private

  def load_heritage
    @heritage = Heritage.find_by!(name: params[:heritage_id])
  end

  def load_release
    @release = @heritage.releases.find_by!(version: params[:version])
  end
end
