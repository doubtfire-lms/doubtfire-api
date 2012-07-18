class DashboardController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_current_user

  def index
    @teams = @user.team_memberships.map{|team_membership| team_membership.team }
    #@projects = @teams.map{|team| team.project }
    @projects = ProjectMembership.joins(:team_membership => :team).where(:team_memberships => {:user_id => params[:id]})
  end

  private

  def load_current_user
    @user = current_user
  end
end