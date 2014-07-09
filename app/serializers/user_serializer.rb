
class UserSerializer < ActiveModel::Serializer
  attributes :id, :email, :name, :first_name, :last_name, :username, :nickname, :role_id
end

class ShallowUserSerializer < ActiveModel::Serializer
  attributes :id, :name, :email
end
