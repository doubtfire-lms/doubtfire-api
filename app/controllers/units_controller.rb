require 'fileutils'

class UnitsController < ApplicationController
  # GET /units
  # GET /units.json
  def index
    @user = current_user
    @units = Unit.all
    @convenors = User.where(system_role:  "convenor")

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @units }
    end
  end

  # GET /units/1
  # GET /units/1.json
  def show
    @unit = Unit.find(params[:id])
    @project_tasks = TaskDefinition.where(unit_id:  params[:id]).order(by:  [:target_date, :id])
    @project_users = User.joins(unit_roles:  :project).where(projects:  {unit_id:  params[:id]})
    @project_tutorials = Tutorial.where(unit_id:  params[:id])
    
    authorize! :manage, @unit, message:  "You are not authorised to manage Unit ##{@unit.id}"
    
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
              task_definitions: {
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
    @convenor_options = UserRole.includes(:user).where(role_id: Role.where(name: 'Convenor').first)
                        .map{|user_role| user_role.user }

    # Create a new unit, populate it with sample data, and save it immediately.
    @unit = Unit.default
    @unit.save
    
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @unit }
      format.js { render action: 'edit' }
    end
  end

  # GET /units/1/edit
  def edit
    @unit = Unit.find(params[:id])
    convenor_role = Role.where(name: 'Convenor').first
    @convenor_options = UserRole.includes(:user).where(role_id: convenor_role.id)
                        .map{|user_role| user_role.user }
    @convenors        = UnitRole.where(unit_id: @unit.id, role_id: convenor_role.id)

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
        convenor_role = Role.where(name: 'Convenor').first

        # Replace the current list of convenors for this project with the new list selected by the user
        unless params[:convenors].nil?
          unit_convenors = UnitRole.where(unit_id: @unit.id, role_id: convenor_role.id)
          removed_convenor_ids = unit_convenors.map(&:user_id) - params[:convenors]
          removed_convenors = unit_convenors.select{|convenor| removed_convenor_ids.include? convenor.user_id }.map(&:id)

          # Delete any convenors that have been removed
          UnitRole.where(id: removed_convenors).destroy_all

          # Find or create convenors
          params[:convenors].each do |convenor_id|
            @convenor_role = UnitRole.find_or_create_by_unit_id_and_user_id_and_role_id(unit_id: @unit.id, user_id: convenor_id, role_id: convenor_role.id)
            @convenor_role.save!
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

  def import_tutorials
    tmp = params[:csv_file][:file].tempfile
    csv_file = File.join("public", params[:csv_file][:file].original_filename)
    FileUtils.cp tmp.path, csv_file

    @unit = Unit.find(params[:unit_id])
    @unit.import_tutorials_from_csv(csv_file)

    FileUtils.rm csv_file

    respond_to do |format|
      format.html { redirect_to unit_path(@unit, tab: "tutorials-tab"), notice: "Successfully imported tutorials."}
      format.js
    end
  end
  
  def destroy_all_tasks
    @unit = Unit.find(params[:unit_id])
    TaskDefinition.destroy_all(unit_id:  @unit.id)
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
        send_data @unit.task_definitions_csv,
        filename: "#{@unit.name.parameterize}-task-defintions.csv"
      }
    end
  end

end
