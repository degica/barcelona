class ReleaseSerializer < ActiveModel::Serializer
  attributes :version, :description, :data

  def data
    object.heritage_params
  end
end
