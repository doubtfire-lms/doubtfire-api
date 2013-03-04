class ConvenorContactFormsController < ApplicationController
  before_filter :authenticate_user!
  
  def new
    @active_projects = ProjectTemplate.set_active
    @convenor_contact_form = ConvenorContactForm.new
  end

  def create
    @convenor_contact_form = ConvenorContactForm.new(params[:convenor_contact_form])

    if @convenor_contact_form.valid?
      @project_template = ProjectTemplate.find(params[:convenor_contact_form][:project_template])  
      
      # Send email message requesting access to the project
      ConvenorContactMailer.request_project_membership(
        current_user, 
        @project_template.project_convenors.first.user, 
        @project_template, 
        params[:convenor_contact_form][:first_name],
        params[:convenor_contact_form][:last_name]
      ).deliver

      flash[:notice] = "Message sent!"
      render :action => 'success'
    else
      flash[:error] = "Please ensure all fields are filled in."
      render :action => 'new'
    end
  end

  def success
    sign_out_and_redirect(current_user)
  end

end
