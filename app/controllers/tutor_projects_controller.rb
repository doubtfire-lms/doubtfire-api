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

    @unmarked_tasks           = unmarked_tasks(@tutor_team_projects)

    @user_unmarked_tasks      = {}

    @unmarked_tasks.each do |unmarked_task|
      user_for_task = unmarked_task.project.team_membership.user

      @user_unmarked_tasks[user_for_task] ||= []
      @user_unmarked_tasks[user_for_task] << unmarked_task
    end

    @other_teams        = Team.includes(:team_memberships => [{:project => [{:tasks => [:task_template]}]}]).where(Team.arel_table[:user_id].not_eq(@user.id), :project_template_id => params[:id]).order(:official_name)
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