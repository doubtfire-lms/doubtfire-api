class ConvenorContactFormsController < ApplicationController
  before_filter :authenticate_user!
  
  def new
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
        params[:convenor_contact_form][:role]
      ).deliver

      flash[:notice] = "Message sent! Thank you for contacting us."
      redirect_to root_url
    else
      flash[:error] = "Please ensure both project and role are selected."
      render :action => 'new'
    end
  end

end
