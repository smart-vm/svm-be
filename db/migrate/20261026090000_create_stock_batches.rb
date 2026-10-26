class CreateStockBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_batches do |t|
      t.references :slot, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.integer :remaining_quantity, null: false
      t.integer :sold_quantity, null: false, default: 0
      # Existing stock has no reliable start date. Never infer it from updated_at.
      t.datetime :stocked_at
      t.datetime :sold_out_at
      t.timestamps
    end

    add_index :stock_batches, [ :slot_id, :id ]
    add_check_constraint :stock_batches,
      "quantity > 0 AND remaining_quantity >= 0 AND sold_quantity >= 0 AND remaining_quantity + sold_quantity <= quantity",
      name: "stock_batches_valid_quantities"
  end
end
