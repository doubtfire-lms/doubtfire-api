class DashboardController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_current_user

  def index
    @projects = @user.team_memberships.map{|tm| tm.project }
  end

  private

  def load_current_user
    @user = current_user
  end
end