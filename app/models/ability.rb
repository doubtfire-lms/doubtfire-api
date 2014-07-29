class Ability
	# include CanCan::Ability

	# def initialize(user)
 #    if user
 #      if user.basic?
 #        can :read, Unit do |unit|
 #          unit.tutorials.map{|tutorial| tutorial.tutor }.include? user
 #        end

 #        can :manage, Unit do |unit|
 #          UnitRole.includes(:user)
 #          .where(unit_id: unit.id, role_id: Role.where(name: 'Convenor'))
 #          .map{|convenor| convenor.user }.include? user
 #        end

 #        can :read, Project do |project|
 #          project.student.user == user || project.student.tutorial.tutor == user
 #        end

 #        can :read, Task do |task|
 #          # TODO: Update this once the idea of groups is
 #          # incorporated
 #          task.project.student.user == user
 #        end

 #        can :manage, Project do |project|
 #          UnitRole.includes(:user)
 #          .where(unit_id: project.unit.id, role_id: Role.where(name: 'Convenor'))
 #          .map{|convenor| convenor.user }.include? user
 #        end
 #      end

 #      # Admin
 #      if user.admin?
 #        can :assign_roles, User
 #  		  can :manage, :all
 #      end
 #    end
	# end
end