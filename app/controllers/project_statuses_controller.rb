class ProjectStatusesController < ApplicationController
  # GET /project_statuses
  # GET /project_statuses.json
  def index
    @project_statuses = ProjectStatus.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @project_statuses }
    end
  end

  # GET /project_statuses/1
  # GET /project_statuses/1.json
  def show
    @project_status = ProjectStatus.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @project_status }
    end
  end

  # GET /project_statuses/new
  # GET /project_statuses/new.json
  def new
    @project_status = ProjectStatus.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @project_status }
    end
  end

  # GET /project_statuses/1/edit
  def edit
    @project_status = ProjectStatus.find(params[:id])
  end

  # POST /project_statuses
  # POST /project_statuses.json
  def create
    @project_status = ProjectStatus.new(params[:project_status])

    respond_to do |format|
      if @project_status.save
        format.html { redirect_to @project_status, notice: 'Project status was successfully created.' }
        format.json { render json: @project_status, status: :created, location: @project_status }
      else
        format.html { render action: "new" }
        format.json { render json: @project_status.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /project_statuses/1
  # PUT /project_statuses/1.json
  def update
    @project_status = ProjectStatus.find(params[:id])

    respond_to do |format|
      if @project_status.update_attributes(params[:project_status])
        format.html { redirect_to @project_status, notice: 'Project status was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @project_status.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /project_statuses/1
  # DELETE /project_statuses/1.json
  def destroy
    @project_status = ProjectStatus.find(params[:id])
    @project_status.destroy

    respond_to do |format|
      format.html { redirect_to project_statuses_url }
      format.json { head :no_content }
    end
  end
end
