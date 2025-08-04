# app/models/payment.rb
class Payment < ApplicationRecord
  belongs_to :sale

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_date, presence: true
  validates :payment_mode, presence: true, inclusion: { 
    in: %w[cash card upi bank_transfer cheque] 
  }

  # Validate that payment doesn't exceed remaining due amount
  validate :amount_not_exceeding_due, on: :create

  # FIXED CALLBACKS - Use correct method names
  after_create :update_sale_amounts
  after_destroy :update_sale_amounts

  scope :recent, -> { order(payment_date: :desc, created_at: :desc) }
  scope :by_mode, ->(mode) { where(payment_mode: mode) if mode.present? }

  def formatted_payment_date
    payment_date.strftime("%d %b %Y")
  end

  def payment_mode_display
    payment_mode.humanize
  end

  private

  def amount_not_exceeding_due
    return unless sale && amount
    
    # For new payments, check against current due amount
    current_due = sale.due_amount || sale.final_amount || 0
    
    if amount > current_due
      errors.add(:amount, "cannot exceed due amount of ₹#{current_due}")
    end
  end

  # FIXED METHOD - Use correct recalculation
  def update_sale_amounts
    return unless sale
    
    sale.reload
    sale.paid_amount = sale.payments.sum(:amount)
    sale.due_amount = [0, sale.final_amount - sale.paid_amount].max
    sale.save! if sale.persisted?
  end
end