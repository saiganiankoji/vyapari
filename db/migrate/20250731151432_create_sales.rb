class CreateSales < ActiveRecord::Migration[7.2]
 def change
    create_table :sales do |t|
      t.references :branch, null: false, foreign_key: true
      t.string :invoice_number, null: false
      
      # Customer details
      t.string :customer_name, null: false
      t.text :customer_address
      t.string :customer_phone
      t.string :customer_gst_number
      
      # Sale details
      t.date :sale_date, null: false
      t.decimal :total_amount, precision: 10, scale: 2, default: 0
      t.decimal :discount_amount, precision: 10, scale: 2, default: 0
      t.decimal :final_amount, precision: 10, scale: 2, default: 0
      
      # Payment details
      t.decimal :paid_amount, precision: 10, scale: 2, default: 0
      t.decimal :due_amount, precision: 10, scale: 2, default: 0
      t.date :due_date
      t.string :payment_status, default: 'pending' # pending, partial, completed, overdue
      
      t.text :notes
      t.timestamps
    end
    
    add_index :sales, :invoice_number, unique: true
    add_index :sales, :customer_name
    add_index :sales, :sale_date
    add_index :sales, :payment_status
    add_index :sales, :due_date
  end
end
