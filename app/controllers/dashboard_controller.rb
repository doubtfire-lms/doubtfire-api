class DashboardController < ApplicationController
  before_filter :authenticate_user!

  def index
    # If user has no projects, redirect
    if @student_projects.empty? and @staff_units.empty?
      # Redirect to the administration page if the user is admin
      if @user.admin?
        redirect_to admin_index_path and return
      else
        redirect_to no_projects_path
      end
    end
  end
end