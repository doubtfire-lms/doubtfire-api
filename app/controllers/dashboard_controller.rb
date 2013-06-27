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

    unit_roles = UnitRole.where(user_id: @user.id, unit_id: @staff_units.map(&:id))
    @users_unit_data  = {}

    unit_roles.each do |role|
      @users_unit_data[role.unit_id] ||= {}
      @users_unit_data[role.unit_id][:roles] ||= []
      @users_unit_data[role.unit_id][:roles] << role.role.name
    end

    tutor_role = Role.where(name: 'Tutor').first

    users_tutor_unit_roles = unit_roles.select{|unit_role| unit_role.role == tutor_role }
    users_tutorials = Tutorial.includes(:projects).where(unit_role_id: users_tutor_unit_roles.map(&:id)) 

    users_tutorials.each do |tutorial|
      @users_unit_data[tutorial.unit_id] ||= {}
      @users_unit_data[tutorial.unit_id][:tutorials] ||= []
      @users_unit_data[tutorial.unit_id][:tutorials] << tutorial
    end
  end
end