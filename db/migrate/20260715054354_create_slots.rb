class CreateSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :slots do |t|
      t.references :machine, null: false, foreign_key: true
      t.integer :slot_number
      t.references :product, null: false, foreign_key: true
      t.integer :current_stock
      t.integer :max_capacity
      t.string :status

      t.timestamps
    end
  end
end
