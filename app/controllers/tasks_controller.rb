class TasksController < ApplicationController
  
  def index
    @projects = current_user.unit_roles.map{|tm| tm.project }
    @project  = Project.find(params[:project_id])
    @tasks    = @project.tasks

    authorize! :read, @project, message:  "You are not authorised to view tasks for Project ##{@project.id}"

    respond_to do |format|
      format.html
      format.json { render json: @tasks}
    end
  end

  def show
    @student_projects = @user.projects.select{|project| project.active? }
    @project          = Project.find(params[:project_id])
    @task             = Task.includes(:task_definition).find(params[:id])

    authorize! :read, @task, message:  "You are not authorised to view Task ##{@task.id}"
  end

  def engage_with_task
    # Grab the task and its engagement status
    @task             = Task.find(params[:id])
    engagement_status = status_for_shortname(params[:status])

    # Engage with the task
    @task.engage engagement_status

    respond_to do |format|
      format.html { redirect_to @project, notice: 'Task was successfully updated.' }
      format.js
    end
  end

  def assess_task
    # Grab the task and its assessment outcome status
    @task                       = Task.find(params[:id])
    @project                    = @task.project
    assessment_outcome_status  = status_for_shortname(params[:status])

    # Assess the task with given status and the current user as the assessor
    @task.assess(assessment_outcome_status, @user)

    respond_to do |format|
      format.html { redirect_to @task.project, notice: 'Task was successfully completed.' }
      format.js
    end
  end

  def submit
    @task                   = Task.find(params[:id])
    @project                = @task.project

    # Task has been submitted only if it's submission status is ready_to_mark
    if params[:submission_status] == "ready_to_mark"
      @task.submit
    end

    respond_to do |format|
      format.html { redirect_to @project, notice: 'Task was successfully submitted.' }
      format.js
    end
  end

  private

  def status_for_shortname(status_shortname)
    status_name = case status_shortname
    when "complete"           then "Complete"
    when "fix_and_resubmit"   then "Fix and Resubmit"
    when "fix_and_include"    then "Fix and Include"
    when "redo"               then "Redo"
    when "not_submitted"      then "Not Submitted"
    when "need_help"          then "Need Help"
    when "working_on_it"      then "Working On It"
    end

    TaskStatus.where(name:  status_name).first
  end
end
