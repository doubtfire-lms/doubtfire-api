class Ability
	include CanCan::Ability

	def initialize(user)
    if user
      if user.regular_user?
        can :read, Unit do |unit|
          unit.tutorials.map{|tutorial| tutorial.tutor }.include? user
        end

        can :read, Project do |project|
          project.student.user == user || project.student.tutorial.tutor == user
        end

        can :read, Task do |task|
          # TODO: Update this once the idea of groups is
          # incorporated
          task.project.student.user == user
        end
      end

      if user.convenor?
        can :manage, Unit do |unit|
          UnitRole.includes(:user)
          .where(unit_id: unit.id, role_id: Role.where(name: 'Convenor'))
          .map{|convenor| convenor.user }.include? user
        end

        can :manage, Project do |project|
          UnitRole.includes(:user)
          .where(unit_id: project.unit.id, role_id: Role.where(name: 'Convenor'))
          .map{|convenor| convenor.user }.include? user
        end

        can :manage, User
      end

      # Superuser
      if user.admin?
        can :assign_roles, User
  		  can :manage, :all
      end
    end
	end
end
