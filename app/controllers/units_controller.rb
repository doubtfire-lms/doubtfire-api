class UnitsController < ApplicationController
  include TutorProjectsHelper

  helper_method :sort_column, :sort_direction

  def show
    @unit = Unit.includes(:task_definitions).find(params[:id])
    authorize! :read, @unit, message:  "You are not authorised to view Unit ##{@unit.id}"

    @unit_roles = UnitRole.where(unit_id: @unit.id, user_id: @user.id)
    @roles      = @unit_roles.map{|unit_role| unit_role.role.name }

    @tabs         = gather_tabs(@roles)
    @selected_tab = params[:selected_tab] || (@tabs[0])
    @selected_tab = @selected_tab.nil? ? nil : @selected_tab.to_sym

    load_unit_summary_data if @roles.include? 'Convenor'
    load_actionable_data if @roles.include? 'Tutor'
  end

  def status_distribution
    @unit = Unit.find(params[:id])

    respond_to do |format|
      format.json {
        render json:
          @unit.to_json(
          methods: [:status_distribution],
          include: [
            {
              task_definitions: {
                except: [:updated_at, :created_at],
                methods: [:status_distribution]
              }
            }
          ]
        )
      }
    end
  end

  private

  def gather_tabs(roles=[])
    tabs = []

    tabs << :summary              if roles.include? 'Convenor'
    tabs << :progress             if roles.include? 'Tutor'
    tabs << :assessment_backlog   if roles.include? 'Tutor'
    tabs << :tutorials            if roles.include? 'Convenor'
    tabs << :tasks                if roles.include? 'Convenor'

    tabs
  end

  def load_unit_summary_data
    sort_options = {
      column: sort_column,
      direction: sort_direction
    }

    @projects = sort_projects(
      Project.includes({
        student: [:user, :tutorial],
        tasks: [:task_definition]
        }, :unit
      )
      .where(
        unit_id: params[:id]
      ).with_progress(gather_included_progress_types),
      sort_options
    )

    @project_tutorials = @projects.map{|project|
      project.student.tutorial
    }.uniq
  end

  def load_actionable_data
    @tutor_unit_role              = @unit_roles.select{|unit_role| unit_role.role.name == 'Tutor' }.first
    @tutor_tutorials              = Tutorial.includes(unit_roles: [{project: [{tasks: [:task_definition]}]}]).where(unit_role_id: @tutor_unit_role.id)
    @tutor_tutorial_projects      = @tutor_tutorials.map{|tutorial| tutorial.unit_roles }.flatten.map{|unit_role| unit_role.project }

    authorize! :read, @unit, message:  "You are not authorised to view Unit ##{@unit.id}"

    @actionable_tasks = {
      awaiting_signoff: user_task_map(unmarked_tasks(@tutor_tutorial_projects)),
      needing_help:     user_task_map(needing_help_tasks(@tutor_tutorial_projects)),
      working_on_it:    user_task_map(working_on_it_tasks(@tutor_tutorial_projects))
    }

    @other_tutorials        = Tutorial.includes(unit_roles:  [{project:  [{tasks:  [:task_definition]}]}])
                              .where("unit_id = ? AND unit_role_id != ?", @unit.id, @tutor_unit_role.id)
                              .order(:code)

    @initial_other_tutorial = @other_tutorials.first
  end

  def gather_included_progress_types
    if params[:progress_excludes] && params[:progress_excludes].is_a?(Array)
      # Get the valid progress exclusions by ensuring they exist (as a symbol) in
      # the list of progress types
      progress_excludes = params[:progress_excludes]
                          .map{|progress| progress.to_sym }
                          .select{|progress| Progress.types.include? progress }

      Progress.types - progress_excludes
    else
      Progress.types
    end
  end

  def sort_column
    %w[username name progress tasks_completed units_completed].include?(params[:sort]) ? params[:sort] : "name"
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
  end

  def sort_projects(projects, options=nil)
    options = {column: "name", direction: "asc"} if options.nil?

    projects = case options[:column]
    when "username"
      projects.sort{|a,b| a.user.username <=> b.user.username }
    when "name"
      projects.sort{|a,b| a.user.name <=> b.user.name }
    when "progress"
      projects.sort{|a,b| -(Progress.new(a.progress) <=> Progress.new(b.progress)) }
    when "tasks_completed"
      projects.sort{|a,b| -(a.completed_tasks.size <=> b.completed_tasks.size) }
    when "units_completed"
      projects.sort{|a,b| -(a.task_units_completed <=> b.task_units_completed) }
    else
      projects.sort{|a,b| a.user.name <=> b.user.name }
    end

    projects.reverse! if options[:direction] == "desc"

    projects
  end
end