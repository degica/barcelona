class UserSerializer < ActiveModel::Serializer
  attributes :name, :public_key, :roles, :token
end
