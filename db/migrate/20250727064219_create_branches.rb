class CreateBranches < ActiveRecord::Migration[7.2]
   def change
    create_table :branches do |t|
      t.string :name, limit: 100
      t.text :address
      t.string :city, limit: 100
      t.string :state, limit: 100
      t.string :pincode, limit: 100
      t.string :manager_name, limit: 100
      t.string :manager_mobile_number, limit: 100
      t.string :email, limit: 100
      t.boolean :is_active, default: true
      t.timestamps
    end
  end
end
