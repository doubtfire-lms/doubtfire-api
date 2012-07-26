class TutorProjectsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_current_user

  def show
    @student_projects         = @user.team_memberships.map{|tm| tm.project }
    @tutor_project_templates  = Team.where(:user_id => @user.id).map{|team| team.project_template }

    @tutor_teams              = Team.where(:user_id => @user.id, :project_template_id => params[:id])
    @tutor_team_projects      = @tutor_teams.map{|team| team.team_memberships }.flatten.map{|team_membership| team_membership.project }

    @project_template         = ProjectTemplate.find(params[:id])
    @unmarked_tasks           = @tutor_team_projects.map{|project| project.tasks }.flatten.select{|task| task.awaiting_signoff }
  end

  def load_current_user
    @user = current_user
  end
end