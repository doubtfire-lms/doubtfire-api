class Api::AuthController < ApplicationController
  skip_before_filter :verify_authenticity_token
  respond_to :json
  before_filter :skip_trackable

  def create
    email = params[:email]
    password = params[:password]

    if email.nil? or password.nil?
     render status: 400, json: { message: "The request must contain the user email and password." }
     return
    end

    @user = User.find_by_email(email.downcase)

    if @user.nil?
      logger.info("User #{email} failed signin, user cannot be found.")
      render status: 401, json: { message: "Invalid email or passoword." }
      return
    end

    @user.ensure_authentication_token!

    if not @user.valid_password?(password)
      logger.info("User #{email} failed signin, password \"#{password}\" is invalid")
      @user.failed_attempts = @user.failed_attempts + 1
      @user.save
      render :status=>401, :json=>{:message=>"Invalid email or password."}
    else
      if @user.failed_attempts < 5
        render status: 200, json: { user: @user, auth_token: @user.authentication_token}
        @user.auth_token_expiry = DateTime.now + 30
        @user.save
      else
        render :status=>401, :json=>{:message=>"Account is Locked."}
      end
    end
  end

  def destroy
    @user=User.find_by_authentication_token(params[:id])
    if @user.nil?
      logger.info("Token not found.")
      render :status=>404, :json=>{:message=>"Invalid token."}
    else
      @user.reset_authentication_token!
      render :status=>200, :json=>{:token=>params[:id]}
    end
  end

  private
  def skip_trackable
    request.env['devise.skip_trackable'] = true
  end
end