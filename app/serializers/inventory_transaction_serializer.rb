# app/serializers/inventory_transaction_serializer.rb
class InventoryTransactionSerializer < ActiveModel::Serializer
  attributes :id, :transaction_type, :transaction_type_display, :quantity, 
             :quantity_display, :balance_after, :source_info, :notes, 
             :formatted_created_at, :created_at

  def transaction_type_display
    object.transaction_type_display
  end

  def quantity_display
    object.quantity_display
  end

  def source_info
    object.source_info
  end

  def formatted_created_at
    object.formatted_created_at
  end

  def created_at
    object.created_at.iso8601
  end
end