class ProductSkuListingSerializer < ActiveModel::Serializer
  attributes :id, :sku_name, :sku_code, :description, :created_at, :updated_at
  
  def created_at
    object.created_at.strftime("%B %d, %Y")
  end
  
  def updated_at
    object.updated_at.strftime("%B %d, %Y")
  end
end