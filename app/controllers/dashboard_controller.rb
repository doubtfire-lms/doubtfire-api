class DashboardController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_current_user

  def index
    # Redirect to the administration page if the user is superuser
    if @user.is_superuser?
      redirect_to superuser_administration_index_path
    elsif @user.is_convenor?
      redirect_to convenor_index_path
    end
    
    @student_projects         = @user.team_memberships.map{|tm| tm.project } || []
    @tutor_project_templates  = Team.where(:user_id => @user.id).map{|team| team.project_template }
  end

  private

  def load_current_user
    @user = current_user
  end
end