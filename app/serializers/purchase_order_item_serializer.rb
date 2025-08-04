# app/serializers/purchase_order_item_serializer.rb
class PurchaseOrderItemSerializer < ActiveModel::Serializer
  attributes :id, :product_sku_id, :quantity, :unit_cost_price, :total_price,
             :sku_name, :sku_code

  def total_price
    object.total_price.to_f
  end

  def unit_cost_price
    object.unit_cost_price.to_f
  end

  def sku_name
    object.product_sku&.sku_name
  end

  def sku_code
    object.product_sku&.sku_code
  end
end