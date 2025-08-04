# app/models/sale.rb - ENHANCED WITH WRITE-OFF SUPPORT

class Sale < ApplicationRecord
  belongs_to :branch
  has_many :sale_items, dependent: :destroy
  has_many :payments, dependent: :destroy
  
  # ENUM FOR SALE STATUS
  enum sale_status: { draft: 0, confirmed: 1 }
  
  accepts_nested_attributes_for :sale_items, 
    allow_destroy: true,
    reject_if: proc { |attributes| 
      attributes['product_sku_id'].blank? || 
      attributes['quantity'].to_i <= 0 
    }
  
  # Validations
  validates :customer_name, presence: true
  validates :branch_id, presence: true
  validates :sale_date, presence: true
  
  # Custom validation to prevent duplicate products
  validate :no_duplicate_products
  
  # Callbacks
  before_save :calculate_amounts
  before_create :generate_invoice_number
  after_update :recalculate_amounts, if: :saved_change_to_any_amount_field?
  
  # Scopes
  scope :overdue, -> { where('due_amount > 0 AND due_date < ?', Date.current) }
  scope :closed, -> { where(is_closed: true) }
  scope :open, -> { where(is_closed: false) }
  scope :with_writeoffs, -> { where('writeoff_amount > 0') }
  scope :confirmed, -> { where(sale_status: 1) }
  
  # =====================
  # WRITE-OFF METHODS
  # =====================
  
  def can_writeoff?
    confirmed? && due_amount > 0 && !is_closed?
  end
  
  def writeoff_remaining_balance!(reason:, authorized_by:, notes: nil)
    return false unless can_writeoff?
    
    transaction do
      writeoff_amount = due_amount
      
      # Update sale with write-off information
      update!(
        writeoff_amount: (self.writeoff_amount || 0) + writeoff_amount,
        writeoff_reason: reason,
        writeoff_date: Date.current,
        writeoff_by: authorized_by,
        is_closed: true,
        closed_date: Date.current,
        closure_notes: notes || "Written off remaining balance of ₹#{writeoff_amount}",
        due_amount: 0  # Clear due amount after write-off
      )
    end
    
    true
  rescue => e
    errors.add(:base, "Failed to write off amount: #{e.message}")
    false
  end
  
  def partial_writeoff!(amount:, reason:, authorized_by:, notes: nil)
    return false unless can_writeoff?
    return false if amount <= 0 || amount > due_amount
    
    transaction do
      current_writeoff = writeoff_amount || 0
      new_writeoff = current_writeoff + amount
      new_due_amount = due_amount - amount
      
      update!(
        writeoff_amount: new_writeoff,
        writeoff_reason: reason,
        writeoff_date: Date.current,
        writeoff_by: authorized_by,
        due_amount: new_due_amount,
        is_closed: new_due_amount <= 0,
        closed_date: new_due_amount <= 0 ? Date.current : nil,
        closure_notes: notes || "Partial write-off of ₹#{amount}"
      )
    end
    
    true
  rescue => e
    errors.add(:base, "Failed to write off amount: #{e.message}")
    false
  end
  
  def close_sale!(reason:, authorized_by:, notes: nil)
    return false unless confirmed?
    
    update!(
      is_closed: true,
      closed_date: Date.current,
      closure_notes: "#{reason}. #{notes}".strip,
      writeoff_by: authorized_by
    )
  end
  
  def reopen_sale!(authorized_by:, notes: nil)
    return false unless is_closed?
    
    update!(
      is_closed: false,
      closed_date: nil,
      closure_notes: "Reopened by #{authorized_by}. #{notes}".strip,
      writeoff_amount: 0,
      writeoff_reason: nil,
      writeoff_date: nil,
      writeoff_by: nil
    )
  end
  
  # =====================
  # STATUS & CALCULATION METHODS
  # =====================
  
  def payment_status_with_writeoff
    return 'closed' if is_closed?
    return 'completed' if due_amount <= 0
    return 'partial' if paid_amount > 0
    return 'overdue' if overdue?
    'pending'
  end
  
  def total_loss
    writeoff_amount || 0
  end
  
  def collection_efficiency
    return 0 if final_amount <= 0
    ((paid_amount / final_amount) * 100).round(2)
  end
  
  def recovery_rate
    return 100 if final_amount <= 0
    (((paid_amount + (writeoff_amount || 0)) / final_amount) * 100).round(2)
  end
  
  def is_fully_recovered?
    due_amount <= 0
  end
  
  def effective_loss_percentage
    return 0 if final_amount <= 0
    (((writeoff_amount || 0) / final_amount) * 100).round(2)
  end
  
  # =====================
  # DISPLAY HELPERS
  # =====================
  
  def closure_status
    return 'Open' unless is_closed?
    return 'Closed - Fully Paid' if due_amount <= 0 && (writeoff_amount || 0) <= 0
    return 'Closed - Partial Write-off' if (writeoff_amount || 0) > 0 && due_amount <= 0
    return 'Closed - Full Write-off' if paid_amount <= 0 && (writeoff_amount || 0) > 0
    'Closed'
  end
  
  def writeoff_summary
    return nil if (writeoff_amount || 0) <= 0
    
    {
      amount: writeoff_amount,
      reason: writeoff_reason,
      date: writeoff_date,
      authorized_by: writeoff_by,
      percentage: effective_loss_percentage
    }
  end
  
  def financial_summary
    {
      final_amount: final_amount,
      paid_amount: paid_amount,
      due_amount: due_amount,
      writeoff_amount: writeoff_amount || 0,
      collection_efficiency: collection_efficiency,
      recovery_rate: recovery_rate,
      loss_percentage: effective_loss_percentage,
      is_closed: is_closed?,
      closure_status: closure_status
    }
  end
  
  # =====================
  # EXISTING METHODS (UNCHANGED)
  # =====================
  
  def can_edit?
    draft?
  end
  
  def can_confirm?
    draft? && sale_items.any?
  end
  
  def can_add_payments?
    confirmed? && !is_closed?
  end
  
  def confirm_sale!
    return false unless can_confirm?
    
    transaction do
      self.sale_status = 'confirmed'
      
      sale_items.each do |item|
        inventory = Inventory.find_by(
          branch: self.branch,
          product_sku: item.product_sku
        )
        
        if inventory
          new_quantity = [0, inventory.quantity - item.quantity].max
          inventory.update!(quantity: new_quantity)
          
          InventoryTransaction.create!(
            inventory: inventory,
            transaction_type: 'sale',
            quantity: -item.quantity,
            balance_after: new_quantity,
            source_type: 'Sale',
            source_id: self.id,
            notes: "Sale #{self.invoice_number}"
          )
        else
          inventory = Inventory.create!(
            branch: self.branch,
            product_sku: item.product_sku,
            quantity: 0,
            min_stock_level: 10
          )
          
          InventoryTransaction.create!(
            inventory: inventory,
            transaction_type: 'sale',
            quantity: -item.quantity,
            balance_after: 0,
            source_type: 'Sale',
            source_id: self.id,
            notes: "Sale #{self.invoice_number} - New inventory record"
          )
        end
      end
      
      save!
    end
    
    true
  end
  
  def add_payment(amount, payment_attributes = {})
    return nil if amount <= 0 || amount > due_amount || is_closed?
    
    payment = payments.build(
      amount: amount,
      payment_date: payment_attributes[:payment_date] || Date.current,
      payment_mode: payment_attributes[:payment_mode] || 'cash',
      reference_number: payment_attributes[:reference_number],
      notes: payment_attributes[:notes]
    )
    
    if payment.save
      self.paid_amount = payments.sum(:amount)
      self.due_amount = [0, final_amount - paid_amount].max
      save! if persisted?
      payment
    else
      nil
    end
  end
  
  def status_info
    case sale_status
    when 'draft'
      'Draft - Can be edited'
    when 'confirmed'
      is_closed? ? "Confirmed - #{closure_status}" : 'Confirmed - Inventory deducted'
    end
  end
  
  def overdue?
    due_date && due_date < Date.current && due_amount > 0 && !is_closed?
  end
  
  def days_overdue
    return 0 unless overdue?
    (Date.current - due_date).to_i
  end
  
  def formatted_sale_date
    sale_date&.strftime('%d/%m/%Y')
  end
  
  def formatted_due_date
    due_date&.strftime('%d/%m/%Y')
  end
  
  private
  
  # Existing private methods remain the same...
  def no_duplicate_products
    return unless sale_items.present?
    
    product_ids = sale_items.reject(&:marked_for_destruction?).map(&:product_sku_id).compact
    
    if product_ids.uniq.length != product_ids.length
      errors.add(:base, 'Cannot have duplicate products in the same sale')
    end
  end
  
  def calculate_amounts
    return unless sale_items.present?
    
    items_total = sale_items.reject(&:marked_for_destruction?).sum do |item|
      item.quantity * item.unit_price
    end
    
    items_discount = sale_items.reject(&:marked_for_destruction?).sum do |item|
      subtotal = item.quantity * item.unit_price
      (subtotal * (item.discount_percentage || 0)) / 100
    end
    
    self.total_amount = items_total
    self.final_amount = [0, items_total - items_discount - (discount_amount || 0)].max
    
    self.paid_amount ||= 0
    self.due_amount = [0, final_amount - paid_amount].max
  end
  
  def recalculate_amounts
    self.paid_amount = payments.sum(:amount)
    self.due_amount = [0, final_amount - paid_amount].max
    update_columns(paid_amount: paid_amount, due_amount: due_amount) if persisted?
  end
  
  def saved_change_to_any_amount_field?
    saved_change_to_final_amount? || saved_change_to_discount_amount?
  end
  
  def generate_invoice_number
    return if invoice_number.present?
    
    prefix = "SALE"
    date_part = (sale_date || Date.current).strftime('%Y%m%d')
    
    last_invoice = Sale.where(
      "invoice_number LIKE ? AND sale_date = ?", 
      "#{prefix}#{date_part}%", 
      sale_date || Date.current
    ).order(:invoice_number).last
    
    if last_invoice
      sequence = last_invoice.invoice_number.last(3).to_i + 1
    else
      sequence = 1
    end
    
    self.invoice_number = "#{prefix}#{date_part}#{sequence.to_s.rjust(3, '0')}"
  end
end