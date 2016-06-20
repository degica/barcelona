class ReleaseSerializer < ActiveModel::Serializer
  attributes :version, :description, :data, :created_at

  def data
    object.app_params
  end
end
