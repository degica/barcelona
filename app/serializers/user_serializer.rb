class UserSerializer < ActiveModel::Serializer
  attributes :name, :public_key, :roles, :districts

  def districts
    object.districts.pluck(:name)
  end
end
