class Api::V1::UserController < ApplicationController
  skip_before_action :authorize_request, except: [:dashboard, :logout]
  before_action :validate_mobile_number, only: [:check_user, :verify_temp_password, :login]
  before_action :throttle_login_attempts, only: [:login, :verify_temp_password]

  LOCKOUT_ATTEMPTS = 3
  RATE_LIMIT = 5 # attempts per minute

  # UI RENDERING ACTIONS
  def login_form
    @mobile_number = params[:mobile_number] || ''
    render layout: 'application'
  end

  def verify_form
    @mobile_number = params[:mobile_number] || ''
    render layout: 'application'
  end

  def dashboard
    @user = current_user
    render layout: 'application'
  end

  def logout
    reset_session
    redirect_to login_path, notice: 'Logged out successfully'
  end

  # API ACTIONS
  def check_user
    user = User.find_by(mobile_number: params[:mobile_number])
    
    if user
      render json: {
        message: "User found", 
        data: { is_user_verified: user.verified }, 
        errors: []
      }, status: :ok
    else
      temp_password = generate_temp_password
      user = User.create!(
        mobile_number: params[:mobile_number],
        password: temp_password,
        verified: false
      )
      
      # Here you would send SMS with temp_password in real implementation
      # For now, we'll just return it in response (remove this in production)
      
      render json: { 
        message: "User created with temporary password", 
        data: { is_user_verified: false }, 
        errors: [] 
      }, status: :created
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message, errors: [e.message] }, status: :unprocessable_entity
  end

  def verify_temp_password
    user = User.find_by(mobile_number: params[:mobile_number])
    
    return render json: { error: "User not found" }, status: :not_found unless user
    return render json: { error: "Account locked" }, status: :forbidden if user.locked?
    
    if user.authenticate(params[:temp_password])
      user.password = params[:new_password]
      if user.has_attribute?(:verified)
        user.verified = true
      end
      user.save!
      
      render json: { 
        message: "Password updated successfully", 
        data: { is_user_verified: true }, 
        errors: [] 
      }, status: :ok
    else
      render json: { error: "Invalid temporary password" }, status: :unauthorized
    end
  end

  def login
    Rails.logger.info "Login attempt for mobile: #{params[:mobile_number]}"
    
    user = User.find_by(mobile_number: params[:mobile_number])
    Rails.logger.info "User found: #{user.present?}"
    
    return render json: { error: "User not found" }, status: :not_found unless user
    return render json: { error: "Account not verified" }, status: :unauthorized unless user.verified?
    return render json: { error: "Account locked" }, status: :forbidden if user.locked?
    
    Rails.logger.info "Attempting authentication..."
    
    if user.authenticate(params[:password])
      Rails.logger.info "Authentication successful"
      
      begin
        token = JsonWebToken.encode(user_id: user.id)
        session[:auth_token] = token
        session[:current_user_id] = user.id
        
        Rails.logger.info "Token generated and session set"
        
        render json: { 
          message: "Login successful", 
          data: { redirect_to: dashboard_path },
          token: token 
        }, status: :ok
      rescue => e
        Rails.logger.error "JWT Error: #{e.message}"
        render json: { error: "Token generation failed: #{e.message}" }, status: :internal_server_error
      end
    else
      Rails.logger.info "Authentication failed"
      render json: { error: "Invalid password" }, status: :unauthorized
    end
  rescue StandardError => e
    Rails.logger.error "Login error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: "Login failed: #{e.message}" }, status: :internal_server_error
  end

  private

  def generate_temp_password
    SecureRandom.alphanumeric(6).upcase
  end

  def validate_mobile_number
    mobile = params[:mobile_number]
    Rails.logger.info "Validating mobile number: #{mobile}"
    
    unless mobile.present? && mobile =~ /\A\d{10}\z/
      Rails.logger.error "Invalid mobile number format: #{mobile}"
      render json: { error: "Invalid mobile number format. Must be 10 digits." }, status: :bad_request
      return false
    end
    true
  end

  def throttle_login_attempts
    ip = request.remote_ip
    key = "login_attempts:#{ip}"
    attempts = Rails.cache.read(key) || 0
    
    if attempts >= RATE_LIMIT
      render json: { error: "Too many attempts. Try again later." }, status: :too_many_requests
      return false
    else
      Rails.cache.write(key, attempts + 1, expires_in: 1.minute)
    end
    true
  end
end