# app/serializers/sale_list_serializer.rb (for index view)
class SaleListSerializer < ActiveModel::Serializer
  attributes :id, :invoice_number, :customer_name, :customer_phone
  attributes :branch_name, :sale_date, :final_amount, :paid_amount, :due_amount
  attributes :payment_status, :due_date, :is_overdue, :days_overdue, :status_color

  def branch_name
    object.branch_name
  end

  def sale_date
    object.formatted_sale_date
  end

  def due_date
    object.due_date&.strftime("%d %b %Y")
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
