# app/serializers/overdue_sale_serializer.rb
class OverdueSaleSerializer < ActiveModel::Serializer
  attributes :id, :invoice_number, :customer_name, :customer_phone
  attributes :branch_name, :due_amount, :due_date, :days_overdue

  def branch_name
    object.branch_name
  end

  def due_date
    object.due_date.strftime("%d %b %Y")
  end

  def days_overdue
    object.days_overdue
  end
end