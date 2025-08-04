# app/models/purchase_order_item.rb
class PurchaseOrderItem < ApplicationRecord
  belongs_to :purchase_order
  belongs_to :product_sku

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_cost_price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Auto-calculate total_price before saving
  before_save :calculate_total_price
  after_save :update_purchase_order_total
  after_destroy :update_purchase_order_total

  # Delegate product info
  delegate :sku_name, :sku_code, to: :product_sku, prefix: false

  # Calculate total price for this item
  def total_price
    (quantity || 0) * (unit_cost_price || 0)
  end

  # Helper methods for display
  def formatted_unit_cost_price
    "₹#{unit_cost_price&.to_f || 0}"
  end

  def formatted_total_price
    "₹#{total_price}"
  end

  private

  def calculate_total_price
    self.total_price = (quantity || 0) * (unit_cost_price || 0)
  end

  def update_purchase_order_total
    # Update the parent purchase order's total amount
    purchase_order.update_column(:total_amount, purchase_order.purchase_order_items.sum(:total_price))
  end
end