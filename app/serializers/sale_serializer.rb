# app/serializers/sale_serializer.rb
class SaleSerializer < ActiveModel::Serializer
  attributes :id, :invoice_number, :customer_name, :customer_phone, :customer_address
  attributes :customer_gst_number, :branch_id, :branch_name, :sale_date, :formatted_sale_date
  attributes :due_date, :total_amount, :discount_amount, :final_amount
  attributes :paid_amount, :due_amount, :payment_status, :notes
  attributes :is_overdue, :days_overdue, :status_color

  has_many :sale_items, serializer: SaleItemSerializer
  has_many :payments, serializer: PaymentSerializer

  def branch_name
    object.branch_name
  end

  def formatted_sale_date
    object.formatted_sale_date
  end

  def sale_date
    object.sale_date.strftime("%Y-%m-%d")
  end

  def due_date
    object.due_date&.strftime("%Y-%m-%d")
  end

  def is_overdue
    object.overdue?
  end

  def days_overdue
    object.days_overdue
  end

  def status_color
    return 'red' if object.overdue?
    
    case object.payment_status
    when 'completed'
      'green'
    when 'partial'
      'orange'
    when 'pending'
      'blue'
    else
      'gray'
    end
  end
end
