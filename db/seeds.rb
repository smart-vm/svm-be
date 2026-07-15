# db/seeds.rb

puts "🧹 Cleaning up existing data..."
Transaction.destroy_all
Slot.destroy_all
Product.destroy_all
Machine.destroy_all

puts "⚙️ Creating Vending Machine node..."
machine = Machine.create!(
  location_name: "Jakarta Public Area - Unit 01",
  status: "active",
  last_heartbeat_at: Time.current
)

puts "📦 Creating Products..."
product_sampoerna = Product.create!(
  name: "Sampoerna A Mild",
  price: 35000.00,
  image_url: "https://example.com/assets/sampoerna_a_mild.png",
  description: "Popular mild kretek cigarette with a light and smooth taste."
)

product_gudang_garam = Product.create!(
  name: "Gudang Garam Surya 16",
  price: 35000.00,
  image_url: "https://example.com/assets/gudang_garam_surya.png",
  description: "Full-flavor kretek with a strong and thick taste."
)

product_djarum = Product.create!(
  name: "Djarum Super",
  price: 30000.00,
  image_url: "https://example.com/assets/djarum_super.png",
  description: "Sweet and strong kretek with a distinctive red packaging."
)

puts "🗄️ Mapping Products to Physical Slots..."
slot_1 = Slot.create!(
  machine: machine,
  product: product_sampoerna,
  slot_number: 1,
  current_stock: 15,
  max_capacity: 20,
  status: "operational"
)

slot_2 = Slot.create!(
  machine: machine,
  product: product_gudang_garam,
  slot_number: 2,
  current_stock: 10,
  max_capacity: 20,
  status: "operational"
)

slot_7 = Slot.create!(
  machine: machine,
  product: product_djarum,
  slot_number: 7, 
  current_stock: 8,
  max_capacity: 10,
  status: "operational"
)

puts "💳 Simulating an active checkout session on Slot 7..."
transaction = Transaction.create!(
  machine: machine,
  slot: slot_7,
  amount: product_djarum.price,
  status: "pending"
)

puts "✅ Seeding Complete!"
puts "--------------------------------------------------"
puts "TESTING VARIABLES FOR POSTMAN / RAILS CONSOLE:"
puts "Machine UUID:     #{machine.uuid}"
puts "Transaction UUID: #{transaction.uuid}"
puts "--------------------------------------------------"