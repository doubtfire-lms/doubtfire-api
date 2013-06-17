class TutorProjectsController < ApplicationController
  include TutorProjectsHelper

  before_filter :authenticate_user!
  before_filter :load_current_user

  def show
    @student_projects         = @user.projects.select{|project| project.active? }
    @tutor_projects           = Tutorial.where(:user_id => @user.id).map{|tutorial| tutorial.unit }.uniq

    @tutor_tutorials              = Tutorial.includes(:unit_roles => [{:project => [{:tasks => [:task_definition]}]}]).where(:user_id => @user.id, :unit_id => params[:id])
    @tutor_tutorial_projects      = @tutor_tutorials.map{|tutorial| tutorial.unit_roles }.flatten.map{|unit_role| unit_role.project }

    @unit         = Unit.find(params[:id])

    authorize! :read, @unit, :message => "You are not authorised to view Unit ##{@unit.id}"

    @actionable_tasks = {
      awaiting_signoff: user_unmarked_tasks(@tutor_tutorial_projects),
      needing_help:     user_needing_help_tasks(@tutor_tutorial_projects),
      working_on_it:    user_working_on_it_tasks(@tutor_tutorial_projects)
    }

    @other_tutorials        = Tutorial.includes(:unit_roles => [{:project => [{:tasks => [:task_definition]}]}])
                              .where("user_id != ? AND unit_id = ?", @user.id, @unit.id)
                              .order(:official_name)

    @initial_other_tutorial = @other_tutorials.first
  end

  def load_current_user
    @user = current_user
  end

  def display_other_tutorial
    @other_tutorial = Tutorial.includes(:unit_roles => [{:project => [{:tasks => [:task_definition]}]}]).find(params[:tutorial_id])
    
    respond_to do |format|
      format.js
    end
  end
end
