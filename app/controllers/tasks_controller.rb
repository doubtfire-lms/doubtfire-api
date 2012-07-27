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

  def update_task_status
    @task               = Task.find(params[:task_id])
    task_status         = TaskStatus.where(:name => params[:status]).first
    @task.task_status   = task_status
    @task.awaiting_signoff = false # Because only staff should be able to change task status

    if @task.complete?
      @task.completion_date = Time.zone.now
    end

    if @task.save
      respond_to do |format|
        format.html { redirect_to @project, notice: 'Task was successfully completed.' }
        format.js
      end
    end
  end

  def awaiting_signoff
    @task                   = Task.find(params[:task_id])
    @task.awaiting_signoff  = params[:awaiting_signoff] != "false"

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