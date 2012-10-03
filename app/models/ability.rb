class Ability
	include CanCan::Ability

	def initialize(user)
    if user
      if user.regular_user?
        can :read, ProjectTemplate do |project_template|
          project_template.teams.map{|team| team.user }.include? user
        end

        can :read, Project do |project|
          project.team_membership.user == user || project.team_membership.team.user == user
        end

        can :read, Task do |task|
          # TODO: Update this once the idea of groups is
          # incorporated
          task.project.team_membership.user == user
        end
      end

      if user.convenor?
        can :manage, ProjectTemplate do |project_template|
          project_template.project_convenors.map{|convenor| convenor.user }.include? user
        end

        can :manage, Project do |project|
          project.project_template.project_convenors.map{|convenor| convenor.user }.include? user
        end

        can :manage, User
      end

      # Superuser
      if user.superuser?
        can :assign_roles, User
  		  can :manage, :all
      end
    end
	end
end