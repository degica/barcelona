class UserSerializer < ActiveModel::Serializer
  attributes :name, :public_key, :token
end
