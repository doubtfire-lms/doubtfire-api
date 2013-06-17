class DashboardController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_current_user

  def index
    # Redirect to the administration page if the user is superuser
    if @user.superuser?
      redirect_to superuser_index_path and return
    elsif @user.convenor?
      redirect_to convenor_index_path and return
    end
    
    @student_projects = @user.projects.select{|project| project.active? }
    @tutor_projects   = Tutorial.includes(:unit)
                            .where(user_id: @user.id).map{|tutorial| tutorial.unit }
                            .select{|unit| unit.active }.uniq

    # If user has no projects, redirect
    if @student_projects.empty? and @tutor_projects.empty?
      redirect_to no_projects_path
    end
  end

  private

  def load_current_user
    @user = current_user
  end
end