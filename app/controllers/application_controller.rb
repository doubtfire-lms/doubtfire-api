class ApplicationController < ActionController::Base
  protect_from_forgery
  before_filter :load_current_user
  before_filter :load_navigation_resources

  private
  
  before_filter :instantiate_controller_and_action_names
 
  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, alert:  exception.message
  end

  def load_current_user
    @user = current_user
  end
 
  def load_navigation_resources
    return if @user.nil?

    @student_projects = @user.projects.select{|project| project.active? }
    @staff_projects   = UnitRole.includes(:unit) # Get the UnitRole and Unit in one
                        .where(user_id: @user.id) # Get the user's unit roles
                        .staff # Filter by staff
                        .map{|unit_role| unit_role.unit } # Grab the unit itself
                        .select(&:active?) # Show only active units
  end

  def instantiate_controller_and_action_names
    @current_action = action_name
    @current_controller = controller_name
  end
end