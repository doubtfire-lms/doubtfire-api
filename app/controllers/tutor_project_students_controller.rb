class TutorProjectStudentsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_current_user

  def show
    @student_project  = Project.includes(:unit).find(params[:project_id])
    @unit             = @student_project.unit
    @student          = @student_project.user

    @student_projects = @user.projects.select{|project| project.active? }
    @tutor_projects   = UnitRole.includes(:unit)
                        .where(user_id: @user.id, role_id: 2).map{|tutorial| tutorial.unit }
                        .select{|unit| unit.active }.uniq

    authorize! :read, @student_project, message: "You are not authorised to view Project ##{@student_project.id}"
  end

  def index
  end

  def load_current_user
    @user = current_user
  end
end