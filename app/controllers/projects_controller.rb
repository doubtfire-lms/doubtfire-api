class ProjectsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_current_user
  before_filter :load_student_projects

  def index
    @projects = Project.where(:team_membership => @user.team_memberships)
  end

  def show
    @project = Project.includes(:tasks => [:task_template]).find(params[:id])
    authorize! :read, @project, :message => "You are not authorised to view Project ##{@project.id}"

    respond_to do |format|
      format.html {render :action => 'show'}
      format.json { 
        render json: @project.to_json(
          :include => [
            {
              :tasks => {:include => {:task_template => {:except=>[:updated_at, :created_at]}}, :except => [:updated_at, :created_at], :methods => [:weight, :status] }
            },
            :project_template => {:except => [:updated_at, :created_at]}
          ],
          :methods => [:progress, :completed_tasks_weight, :total_task_weight, :assigned_tasks],
          :except => [:updated_at, :created_at]
        )
      }
    end
  end

  def load_student_projects
    @student_projects = @user.projects.select{|project| project.active? }
  end

  def load_current_user
    @user = current_user
  end
end