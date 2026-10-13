class CreateAdvertisements < ActiveRecord::Migration[8.1]
  def change
    create_table :advertisements do |t|
      t.string :title, null: false
      # Seconds an image stays on screen; videos play to the end.
      t.integer :duration_seconds, null: false, default: 8
      t.datetime :starts_at
      t.datetime :ends_at
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      # Kiosk screens it may appear on: sidebar, attract, dispensing.
      t.string :placements, array: true, null: false, default: []
      t.timestamps
    end
    add_index :advertisements, [ :active, :position ]

    # No rows for an ad = it runs on every machine.
    create_table :advertisement_machines do |t|
      t.references :advertisement, null: false, foreign_key: true
      t.references :machine, null: false, foreign_key: true
      t.timestamps
    end
    add_index :advertisement_machines, [ :advertisement_id, :machine_id ], unique: true
  end
end
