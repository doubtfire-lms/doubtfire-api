class Ability
	include CanCan::Ability

	def initialize(user)
    if user
      can :read, Project do |project|
        project.team_membership.user == user
      end

      if user.regular_user?
        cannot :access, ProjectTemplate
      end

      # Superuser
      if user.superuser?
        can :assign_roles, User
  		  can :manage, :all
      end
    end
	end
end