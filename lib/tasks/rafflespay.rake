namespace :svm do
  desc "Check the RafflesPay setup: keys, credentials, and one real (unpaid) QRIS payment request. " \
       "Reads .env.rafflespay. AMOUNT_SLOT=<slot number> picks the product (default: cheapest)."
  task rafflespay_check: :environment do
    env_file = Rails.root.join(".env.rafflespay")
    if env_file.exist?
      env_file.each_line do |line|
        key, value = line.strip.split("=", 2).map(&:strip)
        next if key.blank? || key.start_with?("#") || value.nil?
        ENV[key] = value if ENV[key].blank?
      end
    end

    step = ->(label) { print "#{label.ljust(46, '.')} " }
    ok = ->(detail = "ok") { puts detail }
    fail = ->(detail) { puts "FAILED\n  #{detail}"; exit 1 }

    step.("Gateway selected")
    fail.("PAYMENT_GATEWAY is #{Payments.gateway_name.inspect}, set it to raffles_pay") unless Payments.gateway_name == "raffles_pay"
    ok.()

    step.("Client ID and secret present")
    missing = %w[RAFFLESPAY_CLIENT_ID RAFFLESPAY_CLIENT_SECRET].select { |k| ENV[k].blank? }
    fail.("fill in #{missing.join(' and ')} in .env.rafflespay") if missing.any?
    ok.()

    step.("Our private key matches client_public.pem")
    private_pem = Payments::RafflesPayGateway.read_pem("RAFFLESPAY_PRIVATE_KEY")
    ours = OpenSSL::PKey::RSA.new(private_pem)
    public_file = Rails.root.join("config/rafflespay/client_public.pem")
    if public_file.exist? && OpenSSL::PKey::RSA.new(public_file.read).to_der != ours.public_key.to_der
      fail.("client_public.pem is not the public half of the private key")
    end
    ok.("ok (#{ours.n.num_bits}-bit)")

    step.("RafflesPay public key (RPAY) readable")
    begin
      theirs = OpenSSL::PKey::RSA.new(Payments::RafflesPayGateway.read_pem("RAFFLESPAY_PUBLIC_KEY"))
      fail.("that file holds OUR public key; paste the RPAY Public Key instead") if theirs.to_der == ours.public_key.to_der
      ok.()
    rescue Payments::ConfigurationError, OpenSSL::PKey::PKeyError => e
      fail.("#{e.message}. Save the dashboard's RPAY Public Key into config/rafflespay/rpay_public.pem")
    end

    step.("Callback URL is public HTTPS")
    unless Payments.callback_url.start_with?("https://")
      fail.("RafflesPay only accepts an HTTPS callback_url, got #{Payments.callback_url}. " \
            "Set APP_BASE_URL in .env.rafflespay to your HTTPS tunnel or production domain.")
    end
    ok.(Payments.callback_url)

    Payments.gateway = nil # rebuild with the values loaded above
    gateway = Payments.gateway
    machine = Machine.where(status: "active").order(:id).first!
    slot = if ENV["AMOUNT_SLOT"].present?
             machine.slots.find_by!(slot_number: ENV["AMOUNT_SLOT"])
    else
             machine.slots.joins(:product).where("current_stock > 0").order("products.price").first!
    end

    step.("Create QRIS payment (Rp #{slot.product.price.to_i}, not paid)")
    begin
      transaction = Payments::StartCheckout.call(machine: machine, slot: slot, gateway: gateway)
    rescue Payments::Error => e
      fail.(e.message)
    end
    ok.("ok, gateway id #{transaction.external_reference}")

    data = transaction.gateway_payload
    puts "\nWhat RafflesPay returned for QRIS:"
    %w[checkout_url qris_redirect_url qris_image_url qris_image_content redirect_url].each do |field|
      value = data[field]
      shown = value.nil? ? "null" : value.to_s.truncate(90)
      puts "  #{field.ljust(20)} #{shown}"
    end
    raw_qris = data["qris_image_content"].to_s
    puts
    if raw_qris.start_with?(Payments::RafflesPayGateway::QRIS_PAYLOAD_PREFIX)
      puts "GOOD: a raw QRIS string came back. The kiosk shows it and GoPay/OVO/DANA can scan it directly."
    elsif data["qris_image_url"].present?
      puts "OK: a QR image URL came back. The kiosk shows that image; it should scan in GoPay/OVO/DANA."
    else
      puts "PROBLEM: only a checkout link came back. The kiosk can only show a QR of that link, which payment apps reject."
      puts "         Ask RafflesPay how to get the QRIS string or image for your own screen."
    end

    step.("\nRead it back via the status endpoint")
    begin
      status = gateway.fetch_status(transaction.uuid)
      ok.(status ? "ok, status #{status.status}" : "not found (404)")
    rescue Payments::Error => e
      puts "FAILED\n  #{e.message}"
    end

    transaction.cancel!
    puts "\nTest payment #{transaction.uuid} cancelled locally (nothing was charged). " \
         "Open the checkout link above if you want to try paying it from your phone instead."
  end
end
