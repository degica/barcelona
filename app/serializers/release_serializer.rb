class ReleaseSerializer < ActiveModel::Serializer
  attributes :version, :description, :data, :created_at

  def data
    object.heritage_params
  end
end
