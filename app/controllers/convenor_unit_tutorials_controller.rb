class ConvenorUnitTutorialsController < ApplicationController
  def index
    @convenor_units = UnitRole.includes(:unit)
                      .where(user_id: current_user.id, role_id: Role.where(name: 'Convenor').first)
                      .map{|unit_role| unit_role.unit }

    @active_convenor_units   = @convenor_units.select(&:active?)
    @inactive_convenor_units = @convenor_units - @active_convenor_units

    @unit = Unit.includes(:task_definitions).find(params[:id])

    @projects = Project.includes({
                  student: [:user, :tutorial],
                  tasks: [:task_definition]
                  }, :unit
                )
                .where(unit_id: params[:id])

    @projects.sort!{|a,b| a.student.user.name <=> b.student.user.name }

    @project_tutorials = @projects.map {|project|
      project.student.tutorial
    }.uniq
  end

  def show
    @convenor_units = UnitRole.includes(:unit)
                      .where(user_id: current_user.id, role_id: Role.where(name: 'Convenor').first)
                      .map{|unit_role| unit_role.unit }

    @active_convenor_units   = @convenor_units.select(&:active?)
    @inactive_convenor_units = @convenor_units - @active_convenor_units

    @unit = Unit.find(params[:unit_id])
    authorize! :read, @unit, message:  "You are not authorised to view Unit ##{@unit.id}"

    @tutorial             = Tutorial.find(params[:tutorial_id])
  end
end
