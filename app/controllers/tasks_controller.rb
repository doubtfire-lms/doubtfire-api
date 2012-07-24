class TasksController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_current_user

  def index
    @projects = current_user.team_memberships.map{|tm| tm.project }
    @project  = Project.find(params[:project_id])
    @tasks    = @project.tasks

    respond_to do |format|
      format.html
      format.json { render json: @tasks}
    end
  end

  def complete
    @task         = Task.find(params[:task_id])
    @task.task_status  = TaskStatus.where(:name => "Complete").first
    @project      = Project.find(params[:project_id])

    if @task.save
      respond_to do |format|
        format.html { redirect_to @project, notice: 'Task was successfully completed.' }
        format.js
      end
    end
  end

  private 

  def load_current_user
    @user = current_user
  end
end