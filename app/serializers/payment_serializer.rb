# app/serializers/payment_serializer.rb
class PaymentSerializer < ActiveModel::Serializer
  attributes :id, :amount, :payment_date, :formatted_payment_date
  attributes :payment_mode, :reference_number, :notes

  def payment_date
    object.payment_date.strftime("%Y-%m-%d")
  end

  def formatted_payment_date
    object.formatted_payment_date
  end
end
