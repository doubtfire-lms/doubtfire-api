class ConvenorUnitsController < ApplicationController
  helper_method :sort_column, :sort_direction

  def index
    @convenor_units = UnitRole.includes(:unit)
                      .where(user_id: current_user.id, role_id: Role.where(name: 'Convenor').first)
                      .map{|unit_role| unit_role.unit }
                                                                                
    @active_convenor_units   = @convenor_units.select(&:active?)
    @inactive_convenor_units = @convenor_units - @active_convenor_units
  end

	def show
    @convenor_units = UnitRole.includes(:unit)
                      .where(user_id: current_user.id, role_id: Role.where(name: 'Convenor').first)
                      .map{|unit_role| unit_role.unit }
                                                                                
    @active_convenor_units   = @convenor_units.select(&:active?)
    @inactive_convenor_units = @convenor_units - @active_convenor_units
    
		@unit = Unit.includes(:task_definitions).find(params[:id])
    authorize! :read, @unit, message:  "You are not authorised to view Unit ##{@unit.id}"

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

    @project_tutorials = @projects.map {|project|
      project.student.tutorial
    }.uniq
	end

  def export_tasks
    @unit = Unit.includes({projects: [{tasks: :task_definition}, :user]}, :tutorials).find(params[:id])

    respond_to do |format|
      format.html
      format.csv {
        send_data @unit.task_completion_csv,
        filename: "#{@unit.name.parameterize}-task-completion.csv"
      }
    end
  end

  private

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

  def exclusion_filters

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
