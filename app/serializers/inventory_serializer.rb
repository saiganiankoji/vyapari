# app/serializers/inventory_serializer.rb
class InventorySerializer < ActiveModel::Serializer
  attributes :id, :branch_id, :branch_name, :product_sku_id, :sku_name, :sku_code,
             :quantity, :min_stock_level, :last_updated_at, :stock_status,
             :low_stock?, :out_of_stock?, :in_stock?

  def branch_name
    object.branch&.name
  end

  def sku_name
    object.product_sku&.sku_name
  end

  def sku_code
    object.product_sku&.sku_code
  end

  def last_updated_at
    object.last_updated_at&.strftime("%d %b %Y %I:%M %p")
  end

  def stock_status
    object.stock_status
  end

  def low_stock?
    object.low_stock?
  end

  def out_of_stock?
    object.out_of_stock?
  end

  def in_stock?
    object.in_stock?
  end
end