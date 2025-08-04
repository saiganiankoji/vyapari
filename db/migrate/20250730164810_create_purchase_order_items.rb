class CreatePurchaseOrderItems < ActiveRecord::Migration[7.2]
  def change
    create_table :purchase_order_items do |t|
      t.references :purchase_order, null: false, foreign_key: true
      t.references :product_sku, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.decimal :unit_cost_price, precision: 10, scale: 2, null: false
      t.decimal :total_price, precision: 10, scale: 2, null: false
      t.timestamps
    end
  end
end
