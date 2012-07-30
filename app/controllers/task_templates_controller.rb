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

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @task_template }
    end
  end

  # GET /task_templates/new
  # GET /task_templates/new.json
  def new
    @task_template = TaskTemplate.new

    # Create a new task template, populate it with sample data, and save it immediately.
    @task_template.project_template_id = params[:project_template_id]
    @task_template.name = "New Task"
    @task_template.description = "Enter a description for this task."
    @task_template.weighting = 0.0
    @task_template.required = true
    @task_template.recommended_completion_date = Date.today
    @task_template.save

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @task_template }
      format.js { render action: "edit" }
    end
  end

  # GET /task_templates/1/edit
  def edit
    @task_template = TaskTemplate.find(params[:id])

    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST /task_templates
  # POST /task_templates.json
  def create
    @task_template = TaskTemplate.new(params[:task_template])

    respond_to do |format|
      if @task_template.save
        format.html { redirect_to project_template_path(@task_template.project_template_id), notice: "TaskTemplate was successfully updated."}
        format.json { render json: @task_template, status: :created, location: @task_template }
      else
        format.html { render action: "new" }
        format.json { render json: @task_template.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /task_templates/1
  # PUT /task_templates/1.json
  def update
    @task_template = TaskTemplate.find(params[:task_template_id])
    
    respond_to do |format|
      if @task_template.update_attributes(params[:task_template])
        format.html { redirect_to project_template_path(@task_template.project_template_id), notice: "TaskTemplate was successfully updated."}
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
    @project_template = ProjectTemplate.find(@task_template.project_template_id)
    @task_template.destroy

    respond_to do |format|
      format.html { redirect_to project_template_path(@project_template.id), notice: "TaskTemplate was successfully deleted."}
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
