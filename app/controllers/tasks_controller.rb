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
      if @task.needs_fixing? || @task.complete?
        submission = TaskSubmission.where(task_id: @task.id).order(:submission_time).reverse_order.first

        if submission.nil?
          TaskSubmission.create!(task: @task, assessment_time: Time.zone.now, assessor: @user, outcome: task_status.name)
        else
          submission.assessment_time  = Time.zone.now
          submission.assessor         = @user
          submission.outcome          = task_status.name
          submission.save!
        end
      else
        TaskEngagement.create!(task: @task, engagement_time: Time.zone.now, engagement: task_status.name)
      end

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
      submission = TaskSubmission.where(task_id: @task.id).order(:submission_time).reverse_order.first

      if submission.nil?
        TaskSubmission.create!(task: @task, submission_time: Time.zone.now)
      else
        if submission.submission_time < 1.hour.since(Time.zone.now)
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
    when "complete"
      "Complete"
    when "fix"
      "Needs Fixing"
    when "not_submitted"
      "Not Submitted"
    when "need_help"
      "Need Help"
    when "working_on_it"
      "Working On It"
    end

    TaskStatus.where(:name => status_name).first
  end

  def load_current_user
    @user = current_user
  end
end