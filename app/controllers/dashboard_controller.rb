class DashboardController < ApplicationController
  before_filter :authenticate_user!

  def index
    # If user has no projects, redirect
    if @student_projects.empty? and @staff_units.empty?
      # Redirect to the administration page if the user is admin
      if @user.admin?
        redirect_to admin_root_path and return
      else
        redirect_to no_projects_path and return
      end
    end

    @unit_roles = UnitRole.where(user_id: @user.id, unit_id: @staff_units.map(&:id))

    @users_unit_roles = @unit_roles.inject({}) do |roles, role|
      roles[role.unit_id] ||= []
      roles[role.unit_id] << role.role.name
      roles
    end
  end
end