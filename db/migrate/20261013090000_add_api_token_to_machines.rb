class AddApiTokenToMachines < ActiveRecord::Migration[8.1]
  def up
    add_column :machines, :api_token, :string

    # Backfill existing machines so every kiosk can authenticate. Messages are
    # suppressed so the tokens never land in deploy logs.
    suppress_messages do
      select_values("SELECT id FROM machines WHERE api_token IS NULL").each do |id|
        execute "UPDATE machines SET api_token = #{quote(SecureRandom.base58(32))} WHERE id = #{id.to_i}"
      end
    end

    change_column_null :machines, :api_token, false
    add_index :machines, :api_token, unique: true
  end

  def down
    remove_column :machines, :api_token
  end
end
