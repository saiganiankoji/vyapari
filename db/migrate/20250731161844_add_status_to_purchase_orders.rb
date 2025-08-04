class AddStatusToPurchaseOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :purchase_orders, :status, :string, default: 'pending', null: false
    add_column :purchase_orders, :confirmed_at, :datetime
    add_column :purchase_orders, :confirmed_by, :string
    
    add_index :purchase_orders, :status
    add_index :purchase_orders, :confirmed_at
    
    # Update existing records to have 'pending' status
    reversible do |dir|
      dir.up do
        PurchaseOrder.update_all(status: 'pending')
      end
    end
  end
end
