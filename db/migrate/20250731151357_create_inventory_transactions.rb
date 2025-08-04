class CreateInventoryTransactions < ActiveRecord::Migration[7.2]
  def change
    create_table :inventory_transactions do |t|
      t.references :inventory, null: false, foreign_key: true
      t.string :transaction_type # 'purchase', 'sale', 'adjustment'
      t.integer :quantity # positive for in, negative for out
      t.integer :balance_after
      t.references :source, polymorphic: true # PurchaseOrder or Sale
      t.string :notes
      t.timestamps
    end
    
    add_index :inventory_transactions, :transaction_type
    add_index :inventory_transactions, :created_at
  end
end
