class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
    create_table :transactions do |t|
      t.uuid :uuid, default: -> { "gen_random_uuid()" }, null: false
      t.references :machine, null: false, foreign_key: true
      t.references :slot, null: false, foreign_key: true
      t.decimal :amount, precision: 12, scale: 2
      t.string :status
      t.string :external_reference

      t.timestamps
    end
    add_index :transactions, :uuid, unique: true
  end
end
