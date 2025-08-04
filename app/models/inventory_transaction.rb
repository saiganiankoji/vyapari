# app/models/inventory_transaction.rb
class InventoryTransaction < ApplicationRecord
  belongs_to :inventory
  belongs_to :source, polymorphic: true, optional: true

  validates :transaction_type, presence: true, inclusion: { 
    in: %w[purchase sale adjustment transfer] 
  }
  validates :quantity, presence: true, numericality: true
  validates :balance_after, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(transaction_type: type) if type.present? }
  scope :by_date_range, ->(start_date, end_date) {
    where(created_at: start_date..end_date) if start_date.present? && end_date.present?
  }

  # Delegate methods
  delegate :branch_name, :sku_name, :sku_code, to: :inventory, prefix: false

  # Transaction type helpers
  def purchase?
    transaction_type == 'purchase'
  end

  def sale?
    transaction_type == 'sale'
  end

  def adjustment?
    transaction_type == 'adjustment'
  end

  def transfer?
    transaction_type == 'transfer'
  end

  # Display helpers
  def transaction_type_display
    transaction_type.humanize
  end

  def quantity_display
    if quantity > 0
      "+#{quantity}"
    else
      quantity.to_s
    end
  end

  def formatted_created_at
    created_at.strftime("%d %b %Y %I:%M %p")
  end

  # Source information
  def source_info
    return 'Manual Entry' unless source

    case source
    when PurchaseOrder
      "Purchase Order ##{source.po_number}"
    when Sale
      "Sale ##{source.invoice_number}"
    else
      source.class.name
    end
  end
end