class UsersController < ApplicationController

  # GET /users
  # GET /users.json
  def index
    # don't display the current user or the superuser in the users list
    @user = current_user
    @users = User.where("id NOT IN (?)", current_user.id).where("email NOT IN (?)", "superuser@doubtfire.com") 
    
    authorize! :manage, User, :message => "You are not authorised to access user management"

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @users }
    end
  end

  # GET /users/1
  # GET /users/1.json
  def show
    @user = User.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @user }
    end
  end

  # GET /users/new
  # GET /users/new.json
  def new
    @user = User.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @user }
      format.js {
        @user.username           = "username"
        @user.first_name         = "First"
        @user.last_name          = "Last"
        @user.email              = "XXXXXXX@swin.edu.au"
        @user.encrypted_password = BCrypt::Password.create("password")
        @user.nickname           = "noob"
        @user.system_role        = "user"

        @user.save!(:validate => false)
        render action: "edit"
      }
    end
  end

  # GET /users/1/edit
  def edit
    @user = params[:id] ? User.find(params[:id]) : current_user

    respond_to do |format|
      format.html
      format.js
    end
  end

  # POST /users
  # POST /users.json
  def create
    @user = User.new(params[:user])

    respond_to do |format|
      if @user.save
        format.html { redirect_to @user, notice: 'User was successfully created.' }
        format.json { render json: @user, status: :created, location: @user }
      else
        format.html { render action: "new" }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /users/1
  # PUT /users/1.json
  def update

  @user = User.find(params[:id])

	if params[:user][:password].blank?
		params[:user].delete(:password)
	  params[:user].delete(:password_confirmation)
	end

    respond_to do |format|
      if @user.update_attributes(params[:user])

      	# If the user is being updated by the superuser, redirect to the users index instead of the individual user
      	if(@user.superuser?)
	        format.html { redirect_to users_path, notice: 'User was successfully updated.' }
  	    else
  	    	format.html { redirect_to @user, notice: 'User was successfully updated.' }
  	    end

        format.js { render action: "finish_update" }
	      format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @user.errors, status: :unprocessable_entity }
        format.js { render action: "edit" }
      end
    end
  end

  # DELETE /users/1
  # DELETE /users/1.json
  def destroy
    @user = User.find(params[:id])
    @user.destroy

    respond_to do |format|
      format.html { redirect_to users_url }
      format.json { head :no_content }
      format.js  # destroy.js.erb
    end
  end

  # Restores the row in the Teams table to its original state after saving or cancelling from editing mode.
  def finish_update
    @user = User.find(params[:id])

    respond_to do |format|
        format.js  # finish_update.js.erb
    end
  end

  def import
    tmp = params[:csv_file][:file].tempfile
    csv_file = File.join("public", params[:csv_file][:file].original_filename)
    FileUtils.cp tmp.path, csv_file

    User.import_from_csv(csv_file)

    FileUtils.rm csv_file

    respond_to do |format|
      format.js
    end
  end
end
