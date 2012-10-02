class SessionsController < ApplicationController

  def new
  end

  def create
    render :text => request.env["omniauth.auth"].to_yaml
    
    # auth_hash = request.env['omniauth.auth']
    # authentication = Authentication.find_or_create_from_auth_hash(auth_hash)
    # self.current_user = authentication.user
    # redirect_to root_url, :notice => "Logged in successfully."
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_url, :notice => "Signed out!"
  end

  def failure
    flash[:notice] = "Access was not granted, you are not logged in."
  end

end
