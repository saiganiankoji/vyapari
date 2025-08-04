class Branch < ApplicationRecord
  include Filterable
  
  # Validations
  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :address, presence: true
  validates :city, :state, :pincode, :manager_mobile_number, :email, :manager_name,
            length: { maximum: 100 }, allow_blank: true
  validates :manager_mobile_number, 
            uniqueness: true, 
            format: { with: /\A\d{10}\z/, message: "must be a valid 10-digit mobile number" }, 
            allow_blank: true

  # Scopes for filters
  scope :active, ->(value = nil) do
    case value&.to_s&.downcase
    when 'active'
      where(is_active: true)
    when 'inactive'
      where(is_active: false)
    else
      # Return all when value is empty, nil, or any other value
      all
    end
  end

  scope :by_city, ->(city) { where("city ILIKE ?", "%#{city}%") if city.present? }
  scope :by_state, ->(state) { where("state ILIKE ?", "%#{state}%") if state.present? }
  scope :by_name, ->(name) { where("name ILIKE ?", "%#{name}%") if name.present? }

  # Additional helpful scopes
  scope :active_branches, -> { where(is_active: true) }
  scope :inactive_branches, -> { where(is_active: false) }
  scope :ordered_by_name, -> { order(:name) }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods
  def display_status
    is_active? ? 'Active' : 'Inactive'
  end

  def full_address
    [address, city, state, pincode].compact.join(', ')
  end

  def manager_info
    return 'N/A' unless manager_name.present?
    
    info = manager_name
    info += " (#{manager_mobile_number})" if manager_mobile_number.present?
    info += " - #{email}" if email.present?
    info
  end
end