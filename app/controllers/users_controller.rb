class UsersController < ApplicationController
	before_filter :load_current_user, :only => [:edit, :update]

	def show
		@user = User.find(params[:id])
	end

	def edit
	end

	def update
		@user.attributes = params[:user]
    @user.save!
    redirect_to @user, :notice => "Successfully updated profile."
	end

	private

  def load_current_user
    @user = current_user
  end
end