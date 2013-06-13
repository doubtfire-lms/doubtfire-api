class TeamsController < ApplicationController
  # GET /teams
  # GET /teams.json
  def index
    @teams = Team.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @teams }
    end
  end

  # GET /teams/1
  # GET /teams/1.json
  def show
    @team = Team.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @team }
    end
  end

  # GET /teams/new
  # GET /teams/new.json
  def new
    @team = Team.new
    
    # Create a new task definition, populate it with sample data, and save it immediately.
    @team.unit_id = params[:unit_id]
    @team.user_id = current_user.id
    @team.meeting_day = "Enter a regular meeting day."
    @team.meeting_time = "Enter a regular meeting time."
    @team.meeting_location = "Enter a location."
    @team.save

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @team }
      format.js { render action: "edit" }
    end
  end

  # GET /teams/1/edit
  def edit
    @team = Team.find(params[:id])
    
    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST /teams
  # POST /teams.json
  def create
    @team = Team.new(params[:team])

    respond_to do |format|
      if @team.save
        format.html { redirect_to unit_path(@team.unit_id), notice: "Team was successfully updated."}
        format.json { render json: @team, status: :created, location: @team }
      else
        format.html { render action: "new" }
        format.json { render json: @team.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /teams/1
  # PUT /teams/1.json
  def update
    @team = Team.find(params[:team_id])

    respond_to do |format|
      if @team.update_attributes(params[:team])
        format.html { redirect_to unit_path(@team.unit_id), notice: "Team was successfully updated."}
        format.json { head :no_content }
        format.js { render action: "finish_update" }
      else
        format.html { render action: "edit" }
        format.json { render json: @team.errors, status: :unprocessable_entity }
        format.js { render action: "edit" }
      end
    end
  end

  # DELETE /teams/1
  # DELETE /teams/1.json
  def destroy
    @team = Team.find(params[:id])
    @team.destroy

    respond_to do |format|
      format.html { redirect_to teams_url }
      format.json { head :no_content }
      format.js  # destroy.js.erb
    end
  end

  # Restores the row in the Teams table to its original state after saving or cancelling from editing mode.
  def finish_update
    @team = Team.find(params[:team_id])

    respond_to do |format|
        format.js  # finish_update.js.erb
    end
  end
end
