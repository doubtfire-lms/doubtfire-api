class Ability
	include CanCan::Ability

	def initialize(user)
    if user
      can :read, Project do |project|
        project.team_membership.user == user
      end

      can :read, Task do |task|
        # TODO: Update this once the idea of groups is
        # incorporated
        task.project.team_membership.user == user
      end

      if user.regular_user?
        cannot :access, ProjectTemplate
      end

      if user.convenor?
        can :manage, ProjectTemplate do |project_template|
          project_template.project_convenors.map{|convenor| convenor.user }.include? user
        end
      end

      # Superuser
      if user.superuser?
        can :assign_roles, User
  		  can :manage, :all
      end
    end
	end
end