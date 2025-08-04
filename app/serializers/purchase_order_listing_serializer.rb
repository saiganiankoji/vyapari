# app/serializers/purchase_order_listing_serializer.rb
class PurchaseOrderListingSerializer < ActiveModel::Serializer
  attributes :id, :po_number, :vendor_name, :vendor_mobile_number, :vendor_address,
             :vendor_gst_number, :branch_name, :total_amount, :item_count, :total_quantity,
             :formatted_purchase_date, :purchase_date, :status, :confirmed_at, :confirmed_by,
             :is_confirmed, :is_pending, :is_cancelled, :can_be_edited, :can_be_confirmed,
             :can_be_deleted

  def total_amount
    object.total_amount.to_f
  end

  def branch_name
    object.branch&.name
  end

  def item_count
    object.purchase_order_items.count
  end

  def total_quantity
    object.purchase_order_items.sum(:quantity)
  end

  def formatted_purchase_date
    object.purchase_date&.strftime("%d %b %Y")
  end

  def is_confirmed
    object.confirmed?
  end

  def is_pending
    object.pending?
  end

  def is_cancelled
    object.cancelled?
  end

  def can_be_edited
    object.can_be_edited?
  end

  def can_be_confirmed
    object.can_be_confirmed?
  end

  def can_be_deleted
    object.can_be_deleted?
  end
end