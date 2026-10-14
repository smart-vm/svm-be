namespace :svm do
  # RafflesPay's QRIS providers only accept Rp 2.000 and up in practice.
  TEST_PRICES = [ 2000, 2500, 3000 ].freeze

  desc "Add cheap test products (Rp 2.000 / 2.500 / 3.000) to a machine for real-payment testing. " \
       "MACHINE=<uuid or location name> (default: the first active machine), SLOTS=3,4,5"
  task test_products: :environment do
    machine =
      if ENV["MACHINE"].present?
        Machine.find_by(uuid: ENV["MACHINE"]) || Machine.find_by!(location_name: ENV["MACHINE"])
      else
        Machine.where(status: "active").order(:id).first!
      end
    slot_numbers = ENV.fetch("SLOTS", "3,4,5").split(",").map { |s| Integer(s.strip) }
    abort "SLOTS needs #{TEST_PRICES.size} slot numbers" unless slot_numbers.size == TEST_PRICES.size

    puts "Machine: #{machine.location_name} (#{machine.uuid})"

    TEST_PRICES.zip(slot_numbers).each do |price, number|
      product = Product.find_or_initialize_by(name: "Test Item Rp #{ActiveSupport::NumberHelper.number_to_delimited(price, delimiter: '.')}")
      product.update!(price: price, description: "Payment test product. Remove before going live.")
      unless product.image.attached?
        file = Rails.root.join("db/seeds/images/test-item-#{price}.png")
        product.image.attach(io: File.open(file), filename: file.basename.to_s, content_type: "image/png")
      end

      slot = machine.slots.find_or_initialize_by(slot_number: number)
      # Replace an older test item; never a real product.
      if slot.persisted? && slot.product && slot.product != product && !slot.product.name.start_with?("Test Item Rp ")
        puts "  slot #{number}: SKIPPED, holds #{slot.product.name}. Pick other slots with SLOTS=..."
        next
      end

      slot.update!(product: product, current_stock: 10, max_capacity: 10, status: "operational")
      puts "  slot #{number}: #{product.name}"
    end

    puts "Put a physical test item in each of these slots: the motor will turn when a payment succeeds."
  end

  desc "Remove the test products created by svm:test_products"
  task remove_test_products: :environment do
    Product.where("name LIKE ?", "Test Item Rp %").find_each do |product|
      if Transaction.joins(:slot).where(slots: { product_id: product.id }).exists?
        product.slots.update_all(current_stock: 0, status: "disabled")
        puts "#{product.name}: has sales history, slot emptied and disabled instead of deleted"
      else
        product.slots.destroy_all
        product.destroy!
        puts "#{product.name}: removed"
      end
    end
  end
end
