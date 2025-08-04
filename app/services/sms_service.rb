class SmsService
  include HTTParty
  base_uri 'https://api.msg91.com/api'

  def self.send_temp_password(mobile_number, temp_password)
    # For staging/development - log instead of sending real SMS
    unless Rails.env.production?
      Rails.logger.info "SMS: Would send '#{temp_password}' to #{mobile_number}"
      return { success: true, message: "SMS logged for staging" }
    end
    
    # For production - send real SMS
    response = post('/sendotp.php', {
      body: {
        authkey: ENV['MSG91_AUTH_KEY'],
        mobile: mobile_number,
        message: "Your ArunaSolar verification code is: #{temp_password}",
        sender: "ARUNSL",
        route: 4,
        country: 91
      }
    })
    
    Rails.logger.info "SMS API Response: #{response}"
    response
  end
end