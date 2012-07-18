class ProjectsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_current_user

  def show
    @projects = @user.team_memberships.map{|team| team.project.project_template }
  end

  def load_current_user
    @user = current_user
  end
end