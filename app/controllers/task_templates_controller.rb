class TaskTemplatesController < ApplicationController
  # GET /task_templates
  # GET /task_templates.json
  def index
    @task_templates = TaskTemplate.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @task_templates }
    end
  end

  # GET /task_templates/1
  # GET /task_templates/1.json
  def show
    @task_template = TaskTemplate.find(params[:id])
    @unit = @task_template.unit

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @task_template }
    end
  end

  # GET /task_templates/new
  # GET /task_templates/new.json
  def new
    @task_template = TaskTemplate.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @task_template }
      format.js { 
        # Create a new task template and populate it with sample data
        @task_template.unit_id = params[:unit_id]
        @task_template.name = "New Task"
        @task_template.description = "Enter a description for this task."
        @task_template.weighting = 0.0
        @task_template.required = true
        @task_template.target_date = Date.today

        # Call the create action, which saves the object and creates task instances for any existing users
        create()
      }
    end
  end

  # GET /task_templates/1/edit
  def edit
    @task_template = TaskTemplate.includes(:unit).find(params[:id])
    @unit = @task_template.unit

    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST /task_templates
  # POST /task_templates.json
  def create
    # Initialise @task_template from the params unless we are coming from 'new', in which case @task_template already exists.
    @task_template = TaskTemplate.new(params[:task_template]) unless params[:task_template].nil?
    @user_projects = @task_template.unit.projects

    respond_to do |format|
      if @task_template.save
        # Create a task instance for all current users of the project
        @user_projects.each do |project|
          task = Task.new
          task.task_template_id = @task_template.id
          task.project_id = project.id
          task.task_status_id = 1
          task.awaiting_signoff = false 
          task.save!  
        end

        format.html { redirect_to unit_path(@task_template.unit_id), notice: "TaskTemplate was successfully updated."}
        format.js { render action: "edit" }
        format.json { render json: @task_template, status: :created, location: @task_template }
      else
        format.html { render action: "new" }
        format.json { render json: @task_template.errors, status: :unprocessable_entity }
        format.js { render action: "new" }
      end
    end
  end

  # PUT /task_templates/1
  # PUT /task_templates/1.json
  def update
    @task_template = TaskTemplate.find(params[:task_template_id])
    
    respond_to do |format|
      if @task_template.update_attributes(params[:task_template])
        format.html { redirect_to unit_path(@task_template.unit_id), notice: "TaskTemplate was successfully updated."}
        format.json { head :no_content }
        format.js { render action: "finish_update" }
      else
        format.html { render action: "edit" }
        format.json { render json: @task_template.errors, status: :unprocessable_entity }
        format.js { render action: "edit" }
      end
    end
  end

  # DELETE /task_templates/1
  # DELETE /task_templates/1.json
  def destroy
    @task_template = TaskTemplate.find(params[:id])
    @unit = Unit.find(@task_template.unit_id)
    @task_template.destroy

    respond_to do |format|
      format.html { redirect_to unit_path(@unit.id), notice: "TaskTemplate was successfully deleted."}
      format.js
      format.json { head :no_content }
    end
  end

  # Restores the row in the Teams table to its original state after saving or cancelling from editing mode.
  def finish_update
    @task_template = TaskTemplate.find(params[:task_template_id])

    respond_to do |format|
        format.js  # finish_update.js.erb
    end
  end
end
