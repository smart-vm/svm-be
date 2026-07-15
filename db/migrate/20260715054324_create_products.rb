class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name
      t.decimal :price, precision: 12, scale: 2
      t.string :image_url
      t.text :description

      t.timestamps
    end
  end
end
