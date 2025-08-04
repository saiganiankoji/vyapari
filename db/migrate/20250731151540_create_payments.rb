class CreatePayments < ActiveRecord::Migration[7.2]
 def change
    create_table :payments do |t|
      t.references :sale, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.date :payment_date, null: false
      t.string :payment_mode # cash, card, upi, bank_transfer, cheque
      t.string :reference_number
      t.text :notes
      t.timestamps
    end
    
    add_index :payments, :payment_date
    add_index :payments, :payment_mode
  end
end
