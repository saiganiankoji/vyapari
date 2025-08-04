class CreateProductSkus < ActiveRecord::Migration[7.2]
  def change
    create_table :product_skus do |t|
      t.string :sku_name
      t.string :sku_code
      t.text :description

      t.timestamps
    end
  end
end
