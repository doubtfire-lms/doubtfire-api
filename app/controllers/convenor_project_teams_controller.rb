class ConvenorProjectTeamsController < ApplicationController
  def show
    @project_template = ProjectTemplate.find(params[:project_template_id])
    @team             = Team.find(params[:team_id])
  end
end