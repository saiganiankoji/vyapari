class ProductSku < ApplicationRecord
  include Filterable
  
  # Associations
  has_many :purchase_order_items, dependent: :restrict_with_error
  has_many :purchase_orders, through: :purchase_order_items
  has_many :sales_order_items, dependent: :restrict_with_error
  has_many :sales_orders, through: :sales_order_items
  has_many :inventories, dependent: :restrict_with_error

  # Validations
  validates :sku_name, presence: true, length: { maximum: 100 }
  validates :sku_code, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 50 }
  validates :description, length: { maximum: 500 }, allow_blank: true
  
  # Callbacks
  before_save :normalize_sku_code
  
  # Scopes for filters
  scope :by_name, ->(name) { where("sku_name ILIKE ?", "%#{name}%") if name.present? }
  scope :by_code, ->(code) { where("sku_code ILIKE ?", "%#{code}%") if code.present? }
  
  # Additional utility scopes
  scope :ordered_by_name, -> { order(:sku_name) }
  scope :ordered_by_code, -> { order(:sku_code) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_description, -> { where.not(description: [nil, '']) }
  scope :without_description, -> { where(description: [nil, '']) }

  # Instance methods
  def display_name
    "#{sku_name} (#{sku_code})"
  end

  def short_description(limit = 50)
    return 'No description' if description.blank?
    description.length > limit ? "#{description[0..limit-1]}..." : description
  end

  def has_description?
    description.present?
  end

  def formatted_sku_code
    sku_code.upcase
  end

  # Check if product is being used in any orders or inventory
  def in_use?
    purchase_order_items.exists? || sales_order_items.exists? || inventories.exists?
  end

  def usage_summary
    {
      purchase_orders: purchase_orders.count,
      sales_orders: sales_orders.count,
      inventory_records: inventories.count,
      total_usage: purchase_order_items.count + sales_order_items.count + inventories.count
    }
  end

  private

  def normalize_sku_code
    self.sku_code = sku_code.strip.upcase if sku_code.present?
  end
end