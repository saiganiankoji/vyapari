# app/models/inventory.rb
class Inventory < ApplicationRecord
  belongs_to :branch
  belongs_to :product_sku
  has_many :inventory_transactions, dependent: :destroy

  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :min_stock_level, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :low_stock, -> { where('quantity <= min_stock_level') }
  scope :out_of_stock, -> { where(quantity: 0) }
  scope :by_branch, ->(branch_id) { where(branch_id: branch_id) if branch_id.present? }

  # Delegate methods
  delegate :name, to: :branch, prefix: true
  delegate :sku_name, :sku_code, to: :product_sku, prefix: false

  # Stock level checks
  def low_stock?
    quantity <= min_stock_level
  end

  def out_of_stock?
    quantity <= 0
  end

  def in_stock?
    quantity > 0
  end

  # Stock management methods
  def add_stock(qty, source: nil, notes: nil)
    return false if qty <= 0

    ActiveRecord::Base.transaction do
      old_quantity = quantity
      new_quantity = old_quantity + qty
      
      update!(
        quantity: new_quantity,
        last_updated_at: Time.current
      )
      
      # Create transaction record
      inventory_transactions.create!(
        transaction_type: 'purchase',
        quantity: qty,
        balance_after: new_quantity,
        source: source,
        notes: notes
      )
    end
    
    true
  rescue => e
    errors.add(:base, "Failed to add stock: #{e.message}")
    false
  end

  def remove_stock(qty, source: nil, notes: nil)
    return false if qty <= 0 || qty > quantity

    ActiveRecord::Base.transaction do
      old_quantity = quantity
      new_quantity = old_quantity - qty
      
      update!(
        quantity: new_quantity,
        last_updated_at: Time.current
      )
      
      # Create transaction record
      inventory_transactions.create!(
        transaction_type: 'sale',
        quantity: -qty, # negative for removal
        balance_after: new_quantity,
        source: source,
        notes: notes
      )
    end
    
    true
  rescue => e
    errors.add(:base, "Failed to remove stock: #{e.message}")
    false
  end

  def adjust_stock(new_qty, source: nil, notes: nil)
    return false if new_qty < 0

    ActiveRecord::Base.transaction do
      old_quantity = quantity
      adjustment = new_qty - old_quantity
      
      update!(
        quantity: new_qty,
        last_updated_at: Time.current
      )
      
      # Create transaction record
      inventory_transactions.create!(
        transaction_type: 'adjustment',
        quantity: adjustment,
        balance_after: new_qty,
        source: source,
        notes: notes || "Stock adjusted from #{old_quantity} to #{new_qty}"
      )
    end
    
    true
  rescue => e
    errors.add(:base, "Failed to adjust stock: #{e.message}")
    false
  end

  # Check if sufficient stock is available
  def sufficient_stock?(required_qty)
    quantity >= required_qty
  end

  # Formatted methods for display
  def stock_status
    if out_of_stock?
      'Out of Stock'
    elsif low_stock?
      'Low Stock'
    else
      'In Stock'
    end
  end

  def stock_status_color
    if out_of_stock?
      'red'
    elsif low_stock?
      'orange'
    else
      'green'
    end
  end
end