class ProjectTemplatesController < ApplicationController
  # GET /project_templates
  # GET /project_templates.json
  def index
    @user = current_user
    @project_templates = ProjectTemplate.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @project_templates }
    end
  end

  # GET /project_templates/1
  # GET /project_templates/1.json
  def show
    @project_template = ProjectTemplate.find(params[:id])
    @task_templates = TaskTemplate.where(:project_template_id => params[:id])
    @project_users = User.joins(:team_memberships => :project).where(:projects => {:project_template_id => params[:id]})
    @project_teams = Team.where(:project_template_id => params[:id])
    
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

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @project_template }
    end
  end

  # GET /project_templates/1/edit
  def edit
    @project_template = ProjectTemplate.find(params[:id])
    @convenors = User.where(:system_role => "convenor")
  end

  # POST /project_templates
  # POST /project_templates.json
  def create
    @project_template = ProjectTemplate.new(params[:project_template])

    respond_to do |format|
      if @project_template.save
      
        # Convenors can only add themselves as a convenor at the moment
        if current_user.is_convenor?
          @project_administrator = ProjectAdministrator.new(:project_template_id => @project_template.id, :user_id => current_user.id)
          @project_administrator.save
        elsif current_user.is_superuser?
          # For superusers, create a corresponding ProjectAdministrator entry for each convenor
          params[:convenor].each do |convenor_id|
            @project_administrator = ProjectAdministrator.new(:project_template_id => @project_template.id, :user_id => convenor_id)
            @project_administrator.save
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
      else
        format.html { render action: "edit" }
        format.json { render json: @project_template.errors, status: :unprocessable_entity }
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
    end
  end

end