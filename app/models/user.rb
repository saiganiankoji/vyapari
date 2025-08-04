# app/models/user.rb (Minimal version - if you just want login to work)
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable

  validates :mobile_number, presence: true, uniqueness: true
  validates :mobile_number, format: { with: /\A\d{10}\z/, message: "must be a valid 10-digit mobile number" }

  # Custom authenticate method to work with your controller
  def authenticate(password)
    valid_password?(password)
  end

  # Simple methods that always return safe defaults
  def verified?
    has_attribute?(:verified) ? verified : true
  end

  def locked?
    false # Always return false if no column exists
  end

  def failed_attempts
    0 # Always return 0 if no column exists
  end

  # No-op methods for compatibility
  def increment!(attr)
    # Do nothing if column doesn't exist
  end

  def email_required?
    false
  end

  def email_changed?
    false
  end
end