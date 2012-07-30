class TutorProjectsController < ApplicationController
  include TutorProjectsHelper

  before_filter :authenticate_user!
  before_filter :load_current_user

  def show
    @student_projects         = Project.find(@user.team_memberships.map{|membership| membership.project_id })
    @tutor_project_templates  = Team.where(:user_id => @user.id).map{|team| team.project_template }.uniq

    @tutor_teams              = Team.includes(:team_memberships => [{:project => [{:tasks => [:task_template]}]}]).where(:user_id => @user.id, :project_template_id => params[:id])
    @tutor_team_projects      = @tutor_teams.map{|team| team.team_memberships }.flatten.map{|team_membership| team_membership.project }

    @project_template         = ProjectTemplate.find(params[:id])

    @unmarked_tasks           = unmarked_project_tasks(@tutor_team_projects, @user)
  end

  def load_current_user
    @user = current_user
  end
end