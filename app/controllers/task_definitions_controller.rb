class TaskDefinitionsController < ApplicationController
  # GET /task_definitions
  # GET /task_definitions.json
  def index
    @task_definitions = TaskDefinition.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @task_definitions }
    end
  end

  # GET /task_definitions/1
  # GET /task_definitions/1.json
  def show
    @task_definition = TaskDefinition.find(params[:id])
    @unit = @task_definition.unit

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @task_definition }
    end
  end

  # GET /task_definitions/new
  # GET /task_definitions/new.json
  def new
    @task_definition = TaskDefinition.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @task_definition }
      format.js { 
        # Create a new task definition and populate it with sample data
        @task_definition.unit_id = params[:unit_id]
        @task_definition.name = "New Task"
        @task_definition.description = "Enter a description for this task."
        @task_definition.weighting = 0.0
        @task_definition.required = true
        @task_definition.target_date = Date.today

        # Call the create action, which saves the object and creates task instances for any existing users
        create()
      }
    end
  end

  # GET /task_definitions/1/edit
  def edit
    @task_definition = TaskDefinition.includes(:unit).find(params[:id])
    @unit = @task_definition.unit

    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST /task_definitions
  # POST /task_definitions.json
  def create
    # Initialise @task_definition from the params unless we are coming from 'new', in which case @task_definition already exists.
    @task_definition = TaskDefinition.new(params[:task_definition]) unless params[:task_definition].nil?
    @user_projects = @task_definition.unit.projects

    respond_to do |format|
      if @task_definition.save
        # Create a task instance for all current users of the project
        @user_projects.each do |project|
          task = Task.new
          task.task_definition_id = @task_definition.id
          task.project_id = project.id
          task.task_status_id = 1
          task.awaiting_signoff = false 
          task.save!  
        end

        format.html { redirect_to unit_path(@task_definition.unit_id), notice: "TaskDefinition was successfully updated."}
        format.js { render action: "edit" }
        format.json { render json: @task_definition, status: :created, location: @task_definition }
      else
        format.html { render action: "new" }
        format.json { render json: @task_definition.errors, status: :unprocessable_entity }
        format.js { render action: "new" }
      end
    end
  end

  # PUT /task_definitions/1
  # PUT /task_definitions/1.json
  def update
    @task_definition = TaskDefinition.find(params[:task_definition_id])
    
    respond_to do |format|
      if @task_definition.update_attributes(params[:task_definition])
        format.html { redirect_to unit_path(@task_definition.unit_id), notice: "TaskDefinition was successfully updated."}
        format.json { head :no_content }
        format.js { render action: "finish_update" }
      else
        format.html { render action: "edit" }
        format.json { render json: @task_definition.errors, status: :unprocessable_entity }
        format.js { render action: "edit" }
      end
    end
  end

  # DELETE /task_definitions/1
  # DELETE /task_definitions/1.json
  def destroy
    @task_definition = TaskDefinition.find(params[:id])
    @unit = Unit.find(@task_definition.unit_id)
    @task_definition.destroy

    respond_to do |format|
      format.html { redirect_to unit_path(@unit.id), notice: "TaskDefinition was successfully deleted."}
      format.js
      format.json { head :no_content }
    end
  end

  # Restores the row in the Teams table to its original state after saving or cancelling from editing mode.
  def finish_update
    @task_definition = TaskDefinition.find(params[:task_definition_id])

    respond_to do |format|
        format.js  # finish_update.js.erb
    end
  end
end
