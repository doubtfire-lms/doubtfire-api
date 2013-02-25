class ConvenorController < ApplicationController

  before_filter :authenticate_user!
  before_filter :load_current_user

  def index
    @convenor_projects = ProjectTemplate.joins(:project_convenors)
                                        .convened_by(current_user)
                                                                                
    @active_convenor_projects   = @convenor_projects.current
    @inactive_convenor_projects = @convenor_projects.inactive
  end

  def load_current_user
    @user = current_user
  end

end