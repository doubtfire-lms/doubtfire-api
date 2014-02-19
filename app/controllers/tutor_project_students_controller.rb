class TutorProjectStudentsController < ApplicationController
  
  def show
    @student_project  = Project.includes(:unit).find(params[:project_id])
    @unit             = @student_project.unit
    @student          = @student_project.user

    @student_projects = @user.projects.select{|project| project.active? }

    authorize! :read, @student_project, message: "You are not authorised to view Project ##{@student_project.id}"
  end

  def index
  end
end