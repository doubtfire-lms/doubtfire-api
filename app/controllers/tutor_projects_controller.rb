class TutorProjectsController < ApplicationController
  include TutorProjectsHelper

  before_filter :authenticate_user!
  before_filter :load_current_user

  def show
    @student_projects         = @user.projects.select{|project| project.active? }
    @tutor_projects           = Team.where(:user_id => @user.id).map{|team| team.unit }.uniq

    @tutor_teams              = Team.includes(:team_memberships => [{:project => [{:tasks => [:task_template]}]}]).where(:user_id => @user.id, :unit_id => params[:id])
    @tutor_team_projects      = @tutor_teams.map{|team| team.team_memberships }.flatten.map{|team_membership| team_membership.project }

    @unit         = Unit.find(params[:id])

    authorize! :read, @unit, :message => "You are not authorised to view Unit ##{@unit.id}"

    @actionable_tasks = {
      awaiting_signoff: user_unmarked_tasks(@tutor_team_projects),
      needing_help:     user_needing_help_tasks(@tutor_team_projects),
      working_on_it:    user_working_on_it_tasks(@tutor_team_projects)
    }

    @other_teams        = Team.includes(:team_memberships => [{:project => [{:tasks => [:task_template]}]}])
                              .where("user_id != ? AND unit_id = ?", @user.id, @unit.id)
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