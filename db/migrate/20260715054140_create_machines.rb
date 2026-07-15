class CreateMachines < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    create_table :machines do |t|
      t.uuid :uuid, default: -> { "gen_random_uuid()" }, null: false
      t.string :location_name, null: false
      t.string :status, default: 'active', null: false
      t.datetime :last_heartbeat_at

      t.timestamps
    end
    add_index :machines, :uuid, unique: true
  end
end