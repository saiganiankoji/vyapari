# app/models/purchase_order.rb
class PurchaseOrder < ApplicationRecord
  belongs_to :branch
  has_many :purchase_order_items, dependent: :destroy
  has_many :product_skus, through: :purchase_order_items
  has_many :inventory_transactions, as: :source

  validates :po_number, presence: true, uniqueness: true
  validates :vendor_name, presence: true
  validates :purchase_date, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending confirmed cancelled] }
  
  before_validation :generate_po_number, on: :create
  after_save :calculate_total_amount, if: :saved_change_to_any_item_related_field?
  
  accepts_nested_attributes_for :purchase_order_items, 
                                allow_destroy: true, 
                                reject_if: :all_blank

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_branch, ->(branch_id) { where(branch_id: branch_id) if branch_id.present? }
  scope :by_vendor, ->(vendor_name) { where("vendor_name ILIKE ?", "%#{vendor_name}%") if vendor_name.present? }
  scope :by_date_range, ->(start_date, end_date) {
    where(purchase_date: start_date..end_date) if start_date.present? && end_date.present?
  }
  scope :by_status, ->(status) { where(status: status) if status.present? }

  # Status scopes for analytics
  scope :pending, -> { where(status: 'pending') }
  scope :confirmed, -> { where(status: 'confirmed') }
  scope :cancelled, -> { where(status: 'cancelled') }

  # Delegate methods
  delegate :name, to: :branch, prefix: true

  # Status check methods
  def pending?
    status == 'pending'
  end

  def confirmed?
    status == 'confirmed'
  end

  def cancelled?
    status == 'cancelled'
  end

  def can_be_edited?
    pending?
  end

  def can_be_deleted?
    pending?
  end

  def can_be_confirmed?
    pending? && purchase_order_items.any?
  end

  def can_be_cancelled?
    pending?
  end

  # Confirmation method
  def confirm!(user_identifier = nil)
    return false unless can_be_confirmed?
    
    ActiveRecord::Base.transaction do
      # Update inventory for each item
      purchase_order_items.each do |item|
        inventory = Inventory.find_or_initialize_by(
          branch_id: branch_id,
          product_sku_id: item.product_sku_id
        )
        
        # Set default values if this is a new inventory record
        if inventory.new_record?
          inventory.min_stock_level = 10
          inventory.quantity = 0
          inventory.last_updated_at = Time.current
          inventory.save!
        end
        
        # Add stock using the inventory model's method
        inventory.add_stock(
          item.quantity,
          source: self,
          notes: "Purchase Order #{po_number} confirmed"
        )
      end
      
      # Update purchase order status
      update!(
        status: 'confirmed',
        confirmed_at: Time.current,
        confirmed_by: user_identifier
      )
    end
    
    true
  rescue => e
    errors.add(:base, "Failed to confirm order: #{e.message}")
    false
  end

  # Cancel method
  def cancel!(user_identifier = nil)
    return false unless can_be_cancelled?
    
    update!(
      status: 'cancelled',
      confirmed_by: user_identifier # reuse field for who cancelled
    )
    
    true
  rescue => e
    errors.add(:base, "Failed to cancel order: #{e.message}")
    false
  end

  # Calculate total amount from items
  def total_amount
    purchase_order_items.sum(&:total_price) || 0
  end

  # Additional helper methods for serializer
  def item_count
    purchase_order_items.count
  end

  def total_quantity
    purchase_order_items.sum(:quantity) || 0
  end

  # Formatted purchase date for display
  def formatted_purchase_date
    purchase_date&.strftime("%d %b %Y")
  end

  # Boolean helpers for serializer
  def is_confirmed
    confirmed?
  end

  def is_pending
    pending?
  end

  def is_cancelled
    cancelled?
  end

  private

  def generate_po_number
    return if po_number.present?
    
    date_prefix = Date.current.strftime("%Y%m")
    last_order = PurchaseOrder.where("po_number LIKE ?", "PO-#{date_prefix}%")
                              .order(:po_number).last
    
    if last_order
      last_number = last_order.po_number.split('-').last.to_i
      self.po_number = "PO-#{date_prefix}-#{(last_number + 1).to_s.rjust(4, '0')}"
    else
      self.po_number = "PO-#{date_prefix}-0001"
    end
  end

  def calculate_total_amount
    # Recalculate total amount from items
    new_total = purchase_order_items.sum(&:total_price) || 0
    update_column(:total_amount, new_total) unless total_amount == new_total
  end

  def saved_change_to_any_item_related_field?
    # This helps trigger total calculation when items change
    # You can customize this based on your needs
    false # For now, we'll rely on the PurchaseOrderItem callbacks
  end
end