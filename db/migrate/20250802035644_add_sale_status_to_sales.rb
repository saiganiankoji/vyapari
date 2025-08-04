class AddSaleStatusToSales < ActiveRecord::Migration[7.2]
 def change
    add_column :sales, :sale_status, :integer, default: 0, null: false
    add_index :sales, :sale_status
    
    # Set existing sales to 'confirmed' status since inventory was already deducted
    reversible do |dir|
      dir.up do
        # All existing sales become confirmed since inventory was already impacted
        execute "UPDATE sales SET sale_status = 1;" # confirmed
        
        puts "✅ Updated #{Sale.count} existing sales to 'confirmed' status"
        puts "✅ Added sale_status column with index"
      end
    end
  end
end
