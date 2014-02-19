class ConvenorContactFormsController < ApplicationController
  
  def new
    @active_projects = Unit.set_active
    @convenor_contact_form = ConvenorContactForm.new
  end

  def create
    @convenor_contact_form = ConvenorContactForm.new(params[:convenor_contact_form])

    if @convenor_contact_form.valid?
      @unit = Unit.find(params[:convenor_contact_form][:unit])

      # Send email message requesting access to the project
      ConvenorContactMailer.request_project_membership(
        current_user,
        @unit.project_convenors.first.user,
        @unit,
        params[:convenor_contact_form][:first_name],
        params[:convenor_contact_form][:last_name]
      ).deliver

      flash[:notice] = "Message sent!"
      success
    else
      flash[:error] = "Please ensure all fields are filled in."
      render 'new'
    end
  end

  def success
    sign_out_and_redirect(current_user)
  end
end