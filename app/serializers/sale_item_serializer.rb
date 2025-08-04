# app/serializers/sale_item_serializer.rb
class SaleItemSerializer < ActiveModel::Serializer
  attributes :id, :product_sku_id, :quantity, :unit_price
  attributes :discount_percentage, :discount_amount, :total_price
  attributes :product_sku_name, :product_sku_code

  def product_sku_name
    object.product_sku.sku_name
  end

  def product_sku_code
    object.product_sku.sku_code
  end
end
