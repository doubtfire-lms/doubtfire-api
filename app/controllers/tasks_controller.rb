class TasksController < ApplicationController
  before_filter :authenticate_user!

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
    @task                   = Task.find(params[:id])
    task_status             = status_for_shortname(params[:status])
    @task.task_status       = task_status
    @task.awaiting_signoff  = false

    if @task.save
      @task.project.update_attribute(:started, true)
      TaskEngagement.create!(task: @task, engagement_time: Time.zone.now, engagement: task_status.name)

      respond_to do |format|
        format.html { redirect_to @project, notice: 'Task was successfully completed.' }
        format.js
      end
    end
  end

  def assess_task
    # Grab the task and its assessment outcome status
    @task                       = Task.find(params[:id])
    @project                    = @task.project
    @assessment_outcome_status  = status_for_shortname(params[:status])

    # Assess the task with given status and the current user as the assessor
    @task.assess(@assessment_outcome_status, @user)

    respond_to do |format|
      format.html { redirect_to @task.project, notice: 'Task was successfully completed.' }
      format.js
    end
  end

  def submit
    @task                   = Task.find(params[:id])
    @project                = @task.project
    @task.awaiting_signoff  = params[:submission_status] == "ready_to_mark"

    if @task.save
      @project.update_attribute(:started, true)
      submission = TaskSubmission.where(task_id: @task.id).order(:submission_time).reverse_order.first

      if submission.nil?
        TaskSubmission.create!(task: @task, submission_time: Time.zone.now)
      else
        if !submission.submission_time.nil? && submission.submission_time < 1.hour.since(Time.zone.now)
          submission.submission_time = Time.zone.now
          submission.save!
        else
          TaskSubmission.create!(task: @task, submission_time: Time.zone.now)
        end
      end

      respond_to do |format|
        format.html { redirect_to @project, notice: 'Task was successfully completed.' }
        format.js
      end
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
