class CreatePurchaseOrders < ActiveRecord::Migration[7.2]
  def change
    create_table :purchase_orders do |t|
     t.references :branch, null: false, foreign_key: true
      t.string :po_number # Auto-generated PO number
      t.string :vendor_name, null: false
      t.text :vendor_address
      t.string :vendor_mobile_number
      t.string :vendor_gst_number
      t.date :purchase_date, null: false
      t.decimal :total_amount, precision: 10, scale: 2, default: 0.0
      t.text :notes
      t.timestamps
    end
  end
end
