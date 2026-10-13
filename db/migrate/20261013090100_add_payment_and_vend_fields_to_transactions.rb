class AddPaymentAndVendFieldsToTransactions < ActiveRecord::Migration[8.1]
  def change
    change_table :transactions, bulk: true do |t|
      t.string   :payment_method
      t.string   :payment_channel
      t.text     :checkout_url
      t.text     :qr_content
      t.text     :qr_image_url
      t.jsonb    :gateway_payload, default: {}, null: false
      t.jsonb    :callback_payload, default: {}, null: false
      t.decimal  :fee, precision: 12, scale: 2
      t.string   :rrn
      t.string   :issuer_name
      t.string   :failure_reason
      t.jsonb    :vend_result, default: {}, null: false
      t.datetime :expires_at
      t.datetime :paid_at
      t.datetime :dispense_started_at
      t.datetime :dispensed_at
    end

    add_index :transactions, [ :status, :created_at ]
    add_index :transactions, [ :machine_id, :status ]
  end
end
