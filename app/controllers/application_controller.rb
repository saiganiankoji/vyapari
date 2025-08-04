class ApplicationController < ActionController::Base
  before_action :authorize_request
  helper_method :current_user, :logged_in?
  
  protected

  def authorize_request
    token = session[:auth_token]
    
    if token
      begin
        decoded = JsonWebToken.decode(token)
        @current_user = User.find(decoded[:user_id])
      rescue ActiveRecord::RecordNotFound, JWT::DecodeError => e
        reset_session
        redirect_to login_path, alert: 'Please log in to continue'
        return false
      end
    else
      redirect_to login_path, alert: 'Please log in to continue'
      return false
    end
  end

  def current_user
    @current_user
  end

  def logged_in?
    !!current_user
  end
  
  private
  
  def authenticate_user!
    redirect_to login_path, alert: 'Please log in to continue' unless logged_in?
  end
  
  def redirect_if_logged_in
    redirect_to dashboard_path if logged_in?
  end
end