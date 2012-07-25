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

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @task_template }
    end
  end

  # GET /task_templates/1/edit
  def edit
    @task_template = TaskTemplate.find(params[:id])
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
    @task_template = TaskTemplate.find(params[:id])

    respond_to do |format|
      if @task_template.update_attributes(params[:task_template])
        format.html { redirect_to project_template_path(@task_template.project_template_id), notice: "TaskTemplate was successfully updated."}
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @task_template.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /task_templates/1
  # DELETE /task_templates/1.json
  def destroy
    @task_template = TaskTemplate.find(params[:id])
    @task_template.destroy

    respond_to do |format|
      format.html { redirect_to task_templates_url }
      format.json { head :no_content }
    end
  end
end
