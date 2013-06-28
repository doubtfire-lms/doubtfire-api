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
    # Create a default tutorial and give it the associated unit
    @tutorial = Tutorial.default
    @tutorial.unit_id = params[:unit_id]

    @tutorial.save

    tutor_capable_roles = Role.where("name = 'Tutor' OR name = 'Convenor'").map{|role| role.id }
    @tutor_options = UserRole.includes(:user)
                    .where(role_id: [tutor_capable_roles]).map{|user_role| user_role.user }
                    .uniq
                    .sort{|a,b| a.first_name <=> b.first_name }

    @current_tutor = nil

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @tutorial }
      format.js { render 'edit' }
    end
  end

  # GET /tutorials/1/edit
  def edit
    @tutorial = Tutorial.find(params[:id])
    # TODO: Add tutors commonly associated with a given subject
    tutor_capable_roles = Role.where("name = 'Tutor' OR name = 'Convenor'").map{|role| role.id }
    @tutor_options = UserRole.includes(:user)
                    .where(role_id: [tutor_capable_roles]).map{|user_role| user_role.user }
                    .uniq
                    .sort{|a,b| a.first_name <=> b.first_name }

    @current_tutor = @tutorial.tutor.nil? ? nil : @tutorial.tutor.id

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
        format.html { render 'new' }
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

        # If a tutor was set
        unless params[:tutor].nil?
          # Grab the user and change the tutor to be the given user
          new_tutor = User.find(params[:tutor])
          @tutorial.change_tutor(new_tutor)
        end

        format.html { redirect_to unit_path(@tutorial.unit_id), notice: "Tutorial was successfully updated."}
        format.json { head :no_content }
        format.js { render 'finish_update' }
      else
        format.html { render 'edit' }
        format.json { render json: @tutorial.errors, status: :unprocessable_entity }
        format.js { render 'edit' }
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
