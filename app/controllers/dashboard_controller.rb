class DashboardController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_current_user

  def index

    # Redirect to the administration page if the user is superuser
    if @user.is_superuser?
      redirect_to administration_index_path
    end

    @teams = @user.team_memberships.map{|team_membership| team_membership.team }
    @project_templates = @teams.map{|team| team.project_template }
  end

  private

  def load_current_user
    @user = current_user
  end
end