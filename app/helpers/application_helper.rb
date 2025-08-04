# app/helpers/application_helper.rb
module ApplicationHelper
  def body_class
    classes = []
    
    # Add page-specific classes based on controller and action
    classes << "#{controller_name}-controller"
    classes << "#{controller_name}-#{action_name}"
    
    # Add auth-specific classes
    case action_name
    when 'login_form'
      classes << 'auth-page login-page'
    when 'verify_form'
      classes << 'auth-page verify-page'
    when 'dashboard'
      classes << 'dashboard-page'
    end
    
    # Add user status classes if user is present
    if current_user
      classes << 'logged-in'
      classes << (current_user.verified? ? 'user-verified' : 'user-unverified')
    else
      classes << 'logged-out'
    end
    
    classes.join(' ')
  end
  
  def page_title(title = nil)
    if title.present?
      content_for(:title, title)
      "#{title} - ArunaSolar"
    else
      content_for?(:title) ? "#{content_for(:title)} - ArunaSolar" : "ArunaSolar - Solar Management Portal"
    end
  end
  
  def format_mobile_number(number)
    return '' unless number.present?
    cleaned = number.to_s.gsub(/\D/, '')
    return cleaned unless cleaned.length == 10
    "#{cleaned[0..2]}-#{cleaned[3..5]}-#{cleaned[6..9]}"
  end
  
  def user_status_badge(user)
    if user&.verified?
      content_tag :span, 'Verified', class: 'badge badge-success'
    else
      content_tag :span, 'Pending', class: 'badge badge-warning'
    end
  end
end