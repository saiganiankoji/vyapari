# app/serializers/low_stock_serializer.rb
class LowStockSerializer < ActiveModel::Serializer
  attributes :id, :branch_name, :product_sku_name, :product_sku_code
  attributes :quantity, :min_stock_level, :shortage
  
  def branch_name
    object.branch_name
  end
  
  def product_sku_name
    object.product_sku.sku_name
  end
  
  def product_sku_code
    object.product_sku.sku_code
  end
  
  def shortage
    object.min_stock_level - object.quantity
  end
end