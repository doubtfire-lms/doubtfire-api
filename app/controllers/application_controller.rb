class ApplicationController < ActionController::Base
  protect_from_forgery

  private
  
  before_filter :instantiate_controller_and_action_names
 
  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, alert:  exception.message
  end
 
  def instantiate_controller_and_action_names
    @current_action = action_name
    @current_controller = controller_name
  end
end
