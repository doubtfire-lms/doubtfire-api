class TutorialsController < ApplicationController
  # GET /tutorials
  # GET /tutorials.json
  def index
    @tutorials = Tutorial.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @tutorials }
    end
  end

  # GET /tutorials/1
  # GET /tutorials/1.json
  def show
    @tutorial = Tutorial.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @tutorial }
    end
  end

  # GET /tutorials/new
  # GET /tutorials/new.json
  def new
    @tutorial = Tutorial.new
    
    # Create a new task definition, populate it with sample data, and save it immediately.
    @tutorial.unit_id = params[:unit_id]
    @tutorial.user_id = current_user.id
    @tutorial.meeting_day = "Enter a regular meeting day."
    @tutorial.meeting_time = "Enter a regular meeting time."
    @tutorial.meeting_location = "Enter a location."
    @tutorial.save

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @tutorial }
      format.js { render action: "edit" }
    end
  end

  # GET /tutorials/1/edit
  def edit
    @tutorial = Tutorial.find(params[:id])
    
    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST /tutorials
  # POST /tutorials.json
  def create
    @tutorial = Tutorial.new(params[:tutorial])

    respond_to do |format|
      if @tutorial.save
        format.html { redirect_to unit_path(@tutorial.unit_id), notice: "Tutorial was successfully updated."}
        format.json { render json: @tutorial, status: :created, location: @tutorial }
      else
        format.html { render action: "new" }
        format.json { render json: @tutorial.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /tutorials/1
  # PUT /tutorials/1.json
  def update
    @tutorial = Tutorial.find(params[:tutorial_id])

    respond_to do |format|
      if @tutorial.update_attributes(params[:tutorial])
        format.html { redirect_to unit_path(@tutorial.unit_id), notice: "Tutorial was successfully updated."}
        format.json { head :no_content }
        format.js { render action: "finish_update" }
      else
        format.html { render action: "edit" }
        format.json { render json: @tutorial.errors, status: :unprocessable_entity }
        format.js { render action: "edit" }
      end
    end
  end

  # DELETE /tutorials/1
  # DELETE /tutorials/1.json
  def destroy
    @tutorial = Tutorial.find(params[:id])
    @tutorial.destroy

    respond_to do |format|
      format.html { redirect_to tutorials_url }
      format.json { head :no_content }
      format.js  # destroy.js.erb
    end
  end

  # Restores the row in the Tutorials table to its original state after saving or cancelling from editing mode.
  def finish_update
    @tutorial = Tutorial.find(params[:tutorial_id])

    respond_to do |format|
        format.js  # finish_update.js.erb
    end
  end
end
