# app/models/sale_item.rb - FIXED VERSION
class SaleItem < ApplicationRecord
  belongs_to :sale
  belongs_to :product_sku

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_percentage, numericality: { 
    greater_than_or_equal_to: 0, 
    less_than_or_equal_to: 100 
  }, allow_blank: true

  before_save :calculate_amounts
  after_save :update_sale_totals
  after_destroy :update_sale_totals

  delegate :sku_name, :sku_code, to: :product_sku, prefix: :product

  def calculate_amounts
    # Ensure we have valid numbers
    quantity_val = (quantity || 0).to_f
    unit_price_val = (unit_price || 0).to_f
    discount_pct = (discount_percentage || 0).to_f
    
    # Calculate subtotal
    subtotal = quantity_val * unit_price_val
    
    # Calculate discount amount
    discount_amt = subtotal * (discount_pct / 100.0)
    
    # Set calculated values
    self.discount_amount = discount_amt.round(2)
    self.total_price = (subtotal - discount_amt).round(2)
  end

  private

  def update_sale_totals
    # Update the parent sale's totals
    return unless sale&.persisted?
    
    # Only update if sale can be updated (avoid errors during deletion)
    begin
      # Use send to access the private method safely
      sale.send(:calculate_amounts)
      sale.save if sale.changed?
    rescue => e
      # Log the error but don't break the transaction
      Rails.logger.error "Failed to update sale totals: #{e.message}"
    end
  end
end