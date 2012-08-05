class Ability
	include CanCan::Ability

	def initialize(user)
    if user
      # Superuser
      if user.superuser?
        can :assign_roles, User
  		  can :manage, :all
      end
    end
	end
end