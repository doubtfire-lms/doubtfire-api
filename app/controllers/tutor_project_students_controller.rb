class TutorProjectStudentsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_current_user

  def show
    @student_projects         = @user.team_memberships.map{|tm| tm.project }
    @tutor_project_templates  = Team.where(:user_id => @user.id).map{|team| team.project_template }.uniq

    @student_project  = Project.find(params[:project_id]) 
    @student          = User.find(params[:student_id])
  end

  def index
  end

  def load_current_user
    @user = current_user
  end
end