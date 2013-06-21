class TutorProjectsController < ApplicationController
  include TutorProjectsHelper

  before_filter :authenticate_user!
  before_filter :load_current_user

  def show
    @unit                         = Unit.find(params[:id])

    @student_projects             = @user.projects.select{|project| project.active? }
    @tutor_projects               = UnitRole.includes(:unit)
                                    .where(user_id: @user.id, role_id: 2).map{|tutorial| tutorial.unit }
                                    .select{|unit| unit.active }.uniq

    @tutor_unit_role              = UnitRole.where(user_id: @user.id, unit_id: params[:id]).first
    @tutor_tutorials              = Tutorial.includes(unit_roles: [{project: [{tasks: [:task_definition]}]}]).where(unit_role_id: @tutor_unit_role.id)
    @tutor_tutorial_projects      = @tutor_tutorials.map{|tutorial| tutorial.unit_roles }.flatten.map{|unit_role| unit_role.project }

    authorize! :read, @unit, :message => "You are not authorised to view Unit ##{@unit.id}"

    @actionable_tasks = {
      awaiting_signoff: user_unmarked_tasks(@tutor_tutorial_projects),
      needing_help:     user_needing_help_tasks(@tutor_tutorial_projects),
      working_on_it:    user_working_on_it_tasks(@tutor_tutorial_projects)
    }

    @other_tutorials        = Tutorial.includes(:unit_roles => [{:project => [{:tasks => [:task_definition]}]}])
                              .where("unit_id = ? AND unit_role_id != ?", @unit.id, @tutor_unit_role.id)
                              .order(:code)

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
