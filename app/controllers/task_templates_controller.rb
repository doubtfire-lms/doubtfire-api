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
    @project_template = ProjectTemplate.find(params[:project_template_id])

    if not @project_template.nil?
      @task_template.update_attributes(:project_template_id => @project_template.id)
    end

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @task_template }
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
        format.js
      else
        format.html { render action: "edit" }
        format.json { render json: @task_template.errors, status: :unprocessable_entity }
        format.js 
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

  # Updates a task template
  # POST /project_templates/:project_template_id/update_task/:task_template_id
  def update_project_task
    @task_template = TaskTemplate.find(params[:task_template_id])
    
    respond_to do |format|

      # Update each of the model fields from the params. 
      # @TODO:It would be nice to find a better way of doing this.
      @task_template.name = params[:name]
      @task_template.description = params[:description]
      @task_template.weighting = params[:weighting]
      @task_template.required = params[:required]
      @task_template.recommended_completion_date = params[:recommended_completion_date]

      if @task_template.save
        format.html { redirect_to project_template_path(@task_template.project_template_id), notice: "TaskTemplate was successfully updated."}
        format.json { head :no_content }
        format.js
      else
        format.html { render action: "edit" }
        format.json { render json: @task_template.errors, status: :unprocessable_entity }
        format.js 
      end
    end
  end
end
