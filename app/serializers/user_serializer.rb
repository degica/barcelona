class UserSerializer < ActiveModel::Serializer
  attributes :name, :public_key, :roles, :districts, :token

  def districts
    object.districts.pluck(:name)
  end
end
