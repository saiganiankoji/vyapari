class AddWriteoffFieldsToSales < ActiveRecord::Migration[7.2]
 def change
    # Write-off tracking columns
    add_column :sales, :writeoff_amount, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :sales, :writeoff_reason, :string
    add_column :sales, :writeoff_date, :date
    add_column :sales, :writeoff_by, :string  # Who authorized the write-off
    
    # Sale closure tracking
    add_column :sales, :is_closed, :boolean, default: false
    add_column :sales, :closed_date, :date
    add_column :sales, :closure_notes, :text
    
    # Indexes for better performance and reporting
    add_index :sales, :is_closed
    add_index :sales, :writeoff_date
    add_index :sales, :writeoff_amount
  end
end
