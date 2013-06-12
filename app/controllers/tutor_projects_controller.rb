class TutorProjectsController < ApplicationController
  include TutorProjectsHelper

  before_filter :authenticate_user!
  before_filter :load_current_user

  def show
    @student_projects         = Project.find(@user.team_memberships.map{|membership| membership.project_id })
    @tutor_projects           = Team.includes(:project_template)
                                    .where(user_id: @user.id).map{|team| team.project_template }
                                    .select{|project_template| project_template.active }.uniq

    @student_projects         = @user.projects.select{|project| project.active? }
    @tutor_projects           = Team.where(:user_id => @user.id).map{|team| team.project_template }.uniq

    @tutor_teams              = Team.includes(:team_memberships => [{:project => [{:tasks => [:task_template]}]}]).where(:user_id => @user.id, :project_template_id => params[:id])
    @tutor_team_projects      = @tutor_teams.map{|team| team.team_memberships }.flatten.map{|team_membership| team_membership.project }

    @project_template         = ProjectTemplate.find(params[:id])

    authorize! :read, @project_template, :message => "You are not authorised to view Project Template ##{@project_template.id}"

    @actionable_tasks = {
      awaiting_signoff: user_unmarked_tasks(@tutor_team_projects),
      needing_help:     user_needing_help_tasks(@tutor_team_projects),
      working_on_it:    user_working_on_it_tasks(@tutor_team_projects)
    }

    @other_teams        = Team.includes(:team_memberships => [{:project => [{:tasks => [:task_template]}]}])
                              .where("user_id != ? AND project_template_id = ?", @user.id, @project_template.id)
                              .order(:official_name)

    @initial_other_team = @other_teams.first
  end

  def load_current_user
    @user = current_user
  end

  def display_other_team
    @other_team = Team.includes(:team_memberships => [{:project => [{:tasks => [:task_template]}]}]).find(params[:team_id])
    
    respond_to do |format|
      format.js
    end
  end
end