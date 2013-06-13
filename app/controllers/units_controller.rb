require 'fileutils'

class UnitsController < ApplicationController
  # GET /units
  # GET /units.json
  def index
    @user = current_user
    @units = Unit.all
    @convenors = User.where(:system_role => "convenor")

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @units }
    end
  end

  # GET /units/1
  # GET /units/1.json
  def show
    @unit = Unit.find(params[:id])
    @project_tasks = TaskTemplate.where(:unit_id => params[:id]).order(:by => [:target_date, :id])
    @project_users = User.joins(:team_memberships => :project).where(:projects => {:unit_id => params[:id]})
    @project_teams = Team.where(:unit_id => params[:id])
    
    authorize! :manage, @unit, :message => "You are not authorised to manage Unit ##{@unit.id}"
    
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @unit }
    end
  end

  def status_distribution
    @unit = Unit.find(params[:id])
    
    respond_to do |format|
      format.json {
        render json:
          @unit.to_json(
          methods: [:status_distribution],
          include: [
            {
              task_templates: {
                except: [:updated_at, :created_at],
                methods: [:status_distribution]
              }
            }
          ]
        )
      }
    end
  end

  # GET /units/new
  # GET /units/new.json
  def new
    @unit = Unit.new
    @all_convenors = User.where(:system_role => "convenor")
    @project_convenors = User.where(:id => current_user.id);

    # Create a new unit, populate it with sample data, and save it immediately.
    @unit.name = "New Project"
    @unit.description = "Enter a description for this project."
    @unit.start_date = Date.today
    @unit.end_date = 13.weeks.from_now
    @unit.save!
    
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @unit }
      format.js { render action: "edit" }
    end
  end

  # GET /units/1/edit
  def edit
    @unit = Unit.find(params[:id])
    @all_convenors = User.where(:system_role => "convenor")
    @project_convenors = User.joins(:project_convenors).where(:system_role => "convenor", :project_convenors => {:unit_id => @unit.id})

    respond_to do |format|
      format.html # new.html.erb
      format.js   # new.js.erb
    end
  end

  # POST /units
  # POST /units.json
  def create
    @unit = Unit.new(params[:unit])

    respond_to do |format|
      if @unit.save
        format.html { redirect_to @unit, notice: 'Unit was successfully created.' }
        format.json { render json: @unit, status: :created, location: @unit }
      else
        format.html { render action: "new" }
        format.json { render json: @unit.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /units/1
  # PUT /units/1.json
  def update
    @unit = Unit.find(params[:id])
  
    respond_to do |format|
      if @unit.update_attributes(params[:unit])
        # Replace the current list of convenors for this project with the new list selected by the user
        unless params[:convenors].nil?
          ProjectConvenor.where(:unit_id => @unit.id).delete_all
          params[:convenors].each do |convenor_id|
            @project_convenor = ProjectConvenor.find_or_create_by_unit_id_and_user_id(:unit_id => @unit.id, :user_id => convenor_id)
            @project_convenor.save!
          end
        end

        format.html { redirect_to @unit, notice: 'Unit was successfully updated.' }
        format.json { head :no_content }
        format.js { render action: "finish_update" }
      else
        format.html { render action: "edit" }
        format.json { render json: @unit.errors, status: :unprocessable_entity }
        format.js { render action: "edit" }
      end
    end
  end

  # DELETE /units/1
  # DELETE /units/1.json
  def destroy
    @unit = Unit.find(params[:id])
    @unit.destroy

    respond_to do |format|
      format.html { redirect_to units_url }
      format.json { head :no_content }
      format.js
    end
  end

  # Restores the row in the units table to its original state after saving or cancelling from editing mode.
  def finish_update
    @unit = Unit.find(params[:unit_id])

    respond_to do |format|
        format.js  # finish_update.js.erb
    end
  end

  def add_user
    @unit = Unit.find(params[:unit_id])

    respond_to do |format|
      format.js 
    end
  end

  def remove_user
    @unit = Unit.find(params[:unit_id])
    @user = User.find(params[:user_id])

    @unit.remove_user(@user.id)

    respond_to do |format|
      format.js { render "users/destroy.js" }
    end
  end

  def import_users
    tmp = params[:csv_file][:file].tempfile
    csv_file = File.join("public", params[:csv_file][:file].original_filename)
    FileUtils.cp tmp.path, csv_file

    @unit = Unit.find(params[:unit_id])
    @unit.import_users_from_csv(csv_file)

    FileUtils.rm csv_file

    respond_to do |format|
      format.html { redirect_to unit_path(@unit, tab: "participants-tab"), notice: "Successfully imported project participants."}
      format.js
    end
  end

  def import_teams
    tmp = params[:csv_file][:file].tempfile
    csv_file = File.join("public", params[:csv_file][:file].original_filename)
    FileUtils.cp tmp.path, csv_file

    @unit = Unit.find(params[:unit_id])
    @unit.import_teams_from_csv(csv_file)

    FileUtils.rm csv_file

    respond_to do |format|
      format.html { redirect_to unit_path(@unit, tab: "teams-tab"), notice: "Successfully imported teams."}
      format.js
    end
  end
  
  def destroy_all_tasks
    @unit = Unit.find(params[:unit_id])
    TaskTemplate.destroy_all(:unit_id => @unit.id)
  end

  def import_tasks
    tmp = params[:csv_file][:file].tempfile
    csv_file = File.join("public", params[:csv_file][:file].original_filename)
    FileUtils.cp tmp.path, csv_file

    @unit = Unit.find(params[:unit_id])
    @unit.import_tasks_from_csv(csv_file)

    FileUtils.rm csv_file

    respond_to do |format|
      format.html { redirect_to unit_path(@unit, tab: "tasks-tab"), notice: "Successfully imported tasks."}
      format.js
    end
  end

  def export_tasks
    @unit = Unit.find(params[:unit_id])

    respond_to do |format|
      format.html { redirect_to unit_path(@unit, tab: "tasks-tab"), notice: "Successfully imported tasks."}
      format.csv {
        send_data @unit.task_templates_csv,
        filename: "#{@unit.name.parameterize}-task-templates.csv"
      }
    end
  end

end