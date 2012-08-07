class DashboardController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_current_user

  def index
    # Redirect to the administration page if the user is superuser
    if @user.superuser?
      redirect_to superuser_index_path
    elsif @user.convenor?
      redirect_to convenor_index_path
    end
    
    @student_projects         = Project.includes(:tasks).find(@user.team_memberships.map{|membership| membership.project_id })
    @tutor_project_templates  = ProjectTemplate.find(Team.where(:user_id => @user.id).map{|team| team.project_template_id }).uniq
  end

  private

  def load_current_user
    @user = current_user
  end
end