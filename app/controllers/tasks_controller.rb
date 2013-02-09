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
    @task                   = Task.find(params[:id])
    @project                = @task.project
    @student                = @project.team_membership.user

    task_status             = status_for_shortname(params[:status])
    
    @task.task_status       = task_status
    @task.awaiting_signoff  = false # Because only staff should be able to change task status

    if @task.complete?
      @task.completion_date = Time.zone.now
    end

    if @task.save
      @task.project.update_attribute(:started, true)

      if @task.redo? || @task.fix_and_resubmit? || @task.fix_and_include? || @task.complete?
        # Grab the submission for the task if the user made one
        submission = TaskSubmission.where(task_id: @task.id).order(:submission_time).reverse_order.first
        # Prepare the attributes of the submission
        submission_attributes = {task: @task, assessment_time: Time.zone.now, assessor: @user, outcome: task_status.name}

        # Create or update the submission depending on whether one was made
        if submission.nil?
          TaskSubmission.create! submission_attributes
        else
          submission.update_attributes submission_attributes
          submission.save
        end
      end

      respond_to do |format|
        format.html { redirect_to @project, notice: 'Task was successfully completed.' }
        format.js
      end
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

    TaskStatus.where(:name => status_name).first
  end

  def load_current_user
    @user = current_user
  end
end