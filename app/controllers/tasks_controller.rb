class TasksController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_current_user

  def index
    @projects = current_user.team_memberships.map{|tm| tm.project }
    @project  = Project.find(params[:project_id])
    @tasks    = @project.tasks
    authorize! :read, @project, :message => "You are not authorised to view tasks for Project ##{@project.id}"

    respond_to do |format|
      format.html
      format.json { render json: @tasks}
    end
  end

  def show
    @student_projects = Project.find(@user.team_memberships.map{|membership| membership.project_id})
    @project          = Project.find(params[:project_id])
    @task             = Task.includes(:task_template).find(params[:id])

    authorize! :read, @task, :message => "You are not authorised to view Task ##{@task.id}"
  end

  def update_task_status
    @task                   = Task.find(params[:task_id])
    task_status             = status_for_shortname(params[:status])
    @task.task_status       = task_status
    @task.awaiting_signoff  = false # Because only staff should be able to change task status

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

  def status_for_shortname(status_shortname)
    status_name = case status_shortname
    when "complete"
      "Complete"
    when "fix"
      "Needs Fixing"
    when "not_submitted"
      "Not Submitted"
    end

    TaskStatus.where(:name => status_name).first
  end

  def load_current_user
    @user = current_user
  end
end