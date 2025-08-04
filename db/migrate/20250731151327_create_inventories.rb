class CreateInventories < ActiveRecord::Migration[7.2]
  def change
    create_table :inventories do |t|
      t.references :branch, null: false, foreign_key: true
      t.references :product_sku, null: false, foreign_key: true
      t.integer :quantity, default: 0, null: false
      t.integer :min_stock_level, default: 10
      t.datetime :last_updated_at
      t.timestamps
    end
    
    add_index :inventories, [:branch_id, :product_sku_id], unique: true
    add_index :inventories, :quantity
  end
end
