class TasksController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_current_user

  def index
    @projects = current_user.team_memberships.map{|tm| tm.project }
    @project  = Project.find(params[:project_id])
    @tasks    = @project.tasks

    respond_to do |format|
      format.html # index.html.erb
      # format.json { render json: @tasks.to_json(:include => [{:project => {:include => :project_template}}, :task_template]) }

      format.json { render json: @tasks}
    end
  end

  private 

  def load_current_user
    @user = current_user
  end
end