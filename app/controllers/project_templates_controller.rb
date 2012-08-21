require 'fileutils'

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
    @project_tasks = TaskTemplate.where(:project_template_id => params[:id]).order(:by => [:target_date, :id])
    @project_users = User.joins(:team_memberships => :project).where(:projects => {:project_template_id => params[:id]})
    @project_teams = Team.where(:project_template_id => params[:id])
    
    authorize! :manage, @project_template, :message => "You are not authorised to manage Project Template ##{@project_template.id}"
    
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @project_template.to_json(
          :methods => [:status_distribution]
        ) }
    end
  end

  # GET /project_templates/new
  # GET /project_templates/new.json
  def new
    @project_template = ProjectTemplate.new
    @all_convenors = User.where(:system_role => "convenor")
    @project_convenors = User.where(:id => current_user.id);

    # Create a new project template, populate it with sample data, and save it immediately.
    @project_template.name = "New Project"
    @project_template.description = "Enter a description for this project."
    @project_template.start_date = Date.today
    @project_template.end_date = 13.weeks.from_now
    @project_template.save!
    
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @project_template }
      format.js { render action: "edit" }
    end
  end

  # GET /project_templates/1/edit
  def edit
    @project_template = ProjectTemplate.find(params[:id])
    @all_convenors = User.where(:system_role => "convenor")
    @project_convenors = User.joins(:project_convenors).where(:system_role => "convenor", :project_convenors => {:project_template_id => @project_template.id})

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
        # Replace the current list of convenors for this project with the new list selected by the user
        unless params[:convenors].nil?
          ProjectConvenor.where(:project_template_id => @project_template.id).delete_all
          params[:convenors].each do |convenor_id|
            @project_convenor = ProjectConvenor.find_or_create_by_project_template_id_and_user_id(:project_template_id => @project_template.id, :user_id => convenor_id)
            @project_convenor.save!
          end
        end

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
    
    tmp = params[:csv_file][:file].tempfile
    csv_file = File.join("public", params[:csv_file][:file].original_filename)
    FileUtils.cp tmp.path, csv_file

    @project_template = ProjectTemplate.find(params[:project_template_id])
    @project_template.import_users_from_csv(csv_file)

    FileUtils.rm csv_file

    respond_to do |format|
      format.js
    end

  end

  def import_teams
    tmp = params[:csv_file][:file].tempfile
    csv_file = File.join("public", params[:csv_file][:file].original_filename)
    FileUtils.cp tmp.path, csv_file

    @project_template = ProjectTemplate.find(params[:project_template_id])
    @project_template.import_teams_from_csv(csv_file)

    FileUtils.rm csv_file

    respond_to do |format|
      format.js
    end
  end
  
  def destroy_all_tasks
    @project_template = ProjectTemplate.find(params[:project_template_id])
    TaskTemplate.destroy_all(:project_template_id => @project_template.id)
  end

  def import_tasks
    tmp = params[:csv_file][:file].tempfile
    csv_file = File.join("public", params[:csv_file][:file].original_filename)
    FileUtils.cp tmp.path, csv_file

    @project_template = ProjectTemplate.find(params[:project_template_id])
    @project_template.import_tasks_from_csv(csv_file)

    FileUtils.rm csv_file

    respond_to do |format|
      format.js
    end
  end
end