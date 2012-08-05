class ProjectTemplatesController < ApplicationController
  # GET /project_templates
  # GET /project_templates.json
  def index
    @user = current_user
    @project_templates = ProjectTemplate.all
    @convenors = User.where(:system_role => "convenor")

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @project_templates }
    end
  end

  # GET /project_templates/1
  # GET /project_templates/1.json
  def show
    @project_template = ProjectTemplate.find(params[:id])
    @project_tasks = TaskTemplate.where(:project_template_id => params[:id])
    @project_users = User.joins(:team_memberships => :project).where(:projects => {:project_template_id => params[:id]})
    @project_teams = Team.where(:project_template_id => params[:id])
    
    authorize! :access, @project_template, :message => "You are not authorised to view Project Template ##{@project_template.id}"

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @project_template }
    end
  end

  # GET /project_templates/new
  # GET /project_templates/new.json
  def new
    @project_template = ProjectTemplate.new
    @convenors = User.where(:system_role => "convenor")

    # Create a new project template, populate it with sample data, and save it immediately.
    @project_template.name = "New Project"
    @project_template.description = "Enter a description for this project."
    @project_template.start_date = Date.today
    @project_template.end_date = 13.weeks.from_now
    
    if @project_template.save
      ProjectConvenor.populate(1) do |project_admin|
        project_admin.user_id = current_user.id
        project_admin.project_template_id = @project_template.id
      end
    end

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @project_template }
      format.js { render action: "edit" }
    end
  end

  # GET /project_templates/1/edit
  def edit
    @project_template = ProjectTemplate.find(params[:id])
    @convenors = User.where(:system_role => "convenor")

    respond_to do |format|
      format.html # new.html.erb
      format.js   # new.js.erb
    end
  end

  # POST /project_templates
  # POST /project_templates.json
  def create
    @project_template = ProjectTemplate.new(params[:project_template])

    respond_to do |format|
      if @project_template.save
      
        # Convenors can only add themselves as a convenor at the moment
        if current_user.convenor?
          @project_convenor = ProjectConvenor.new(:project_template_id => @project_template.id, :user_id => current_user.id)
          @project_convenor.save
        elsif current_user.superuser?
          # For superusers, create a corresponding ProjectConvenor entry for each convenor
          params[:convenor].each do |convenor_id|
            @project_convenor = ProjectConvenor.new(:project_template_id => @project_template.id, :user_id => convenor_id)
            @project_convenor.save
          end
        end

        format.html { redirect_to @project_template, notice: 'ProjectTemplate was successfully created.' }
        format.json { render json: @project_template, status: :created, location: @project_template }
      else
        format.html { render action: "new" }
        format.json { render json: @project_template.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /project_templates/1
  # PUT /project_templates/1.json
  def update
    @project_template = ProjectTemplate.find(params[:id])

    respond_to do |format|
      if @project_template.update_attributes(params[:project_template])
        format.html { redirect_to @project_template, notice: 'ProjectTemplate was successfully updated.' }
        format.json { head :no_content }
        format.js { render action: "finish_update" }
      else
        format.html { render action: "edit" }
        format.json { render json: @project_template.errors, status: :unprocessable_entity }
        format.js { render action: "edit" }
      end
    end
  end

  # DELETE /project_templates/1
  # DELETE /project_templates/1.json
  def destroy
    @project_template = ProjectTemplate.find(params[:id])
    @project_template.destroy

    respond_to do |format|
      format.html { redirect_to project_templates_url }
      format.json { head :no_content }
      format.js
    end
  end

  # Restores the row in the project templates table to its original state after saving or cancelling from editing mode.
  def finish_update
    @project_template = ProjectTemplate.find(params[:id])

    respond_to do |format|
        format.js  # finish_update.js.erb
    end
  end

  def add_user
    @project_template = ProjectTemplate.find(params[:project_template_id])

    respond_to do |format|
      format.js 
    end
  end

  def remove_user
    @project_template = ProjectTemplate.find(params[:project_template_id])
    @user = User.find(params[:user_id])

    @project_template.remove_user(@user.id)

    respond_to do |format|
      format.js { render "users/destroy.js" }
    end
  end

  def import_users
    
    @project_template = ProjectTemplate.find(params[:project_template_id])
    @project_template.import_users_from_csv(params[:csv_file][:file])

    respond_to do |format|
      format.js
    end

  end

end