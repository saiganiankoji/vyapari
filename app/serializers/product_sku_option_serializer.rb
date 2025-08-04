# app/serializers/product_sku_option_serializer.rb (for dropdowns)
class ProductSkuOptionSerializer < ActiveModel::Serializer
  attributes :id, :name, :code

  def name
    object.sku_name
  end

  def code
    object.sku_code
  end
end