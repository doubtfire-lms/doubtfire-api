
class UserSerializer < ActiveModel::Serializer
  attributes :id, :email, :name, :first_name, :last_name, :username, :nickname, :system_role

	def system_role
		object.role.name
	end

end

class ShallowUserSerializer < ActiveModel::Serializer
  attributes :id, :name, :email
end
