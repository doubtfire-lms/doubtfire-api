class ConvenorProjectsController < ApplicationController
  helper_method :sort_column, :sort_direction

	def show
		@project_template = ProjectTemplate.includes(:task_templates).find(params[:id])
    authorize! :read, @project_template, :message => "You are not authorised to view Project Template ##{@project_template.id}"

    sort_options = {
      column: sort_column,
      direction: sort_direction
    }

    @projects = sort_projects(
                  Project.includes({
                    team_membership: [:user, :team],
                    tasks: [:task_template]
                    }, :project_template
                  )
                  .where(
                    project_template_id: params[:id]
                  ).with_progress(gather_included_progress_types),
                  sort_options
                )

    @project_teams = @projects.map {|project|
      project.team_membership.team
    }.uniq
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