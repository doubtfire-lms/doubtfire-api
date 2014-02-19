class UserSerializer < ActiveModel::Serializer
  attributes :id, :email, :name, :first_name, :last_name, :username, :nickname, :system_role
end
