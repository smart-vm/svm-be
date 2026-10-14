require "test_helper"

class Payments::StartCheckoutTest < ActiveSupport::TestCase
  test "creates a pending transaction with the gateway checkout" do
    transaction = Payments::StartCheckout.call(machine: machines(:one), slot: slots(:one))

    assert transaction.pending?
    assert_equal BigDecimal("15000"), transaction.amount
    assert_equal "qris", transaction.payment_method
    assert_match %r{/mock_gateway/checkouts/#{transaction.uuid}\z}, transaction.checkout_url
    assert transaction.external_reference.start_with?("mock_")
    assert_in_delta Payments.expires_in.from_now, transaction.expires_at, 5
  end

  test "cancels the previous QR still on screen" do
    previous = transactions(:one)

    Payments::StartCheckout.call(machine: machines(:one), slot: slots(:one))

    assert previous.reload.cancelled?
  end

  test "refuses an empty slot, a foreign slot, and a busy machine" do
    slots(:one).update!(current_stock: 0)
    assert_raises(Payments::StartCheckout::Invalid) { Payments::StartCheckout.call(machine: machines(:one), slot: slots(:one)) }

    assert_raises(Payments::StartCheckout::Invalid) { Payments::StartCheckout.call(machine: machines(:one), slot: slots(:two)) }

    slots(:one).update!(current_stock: 3)
    transactions(:one).update!(status: "dispensing")
    assert_raises(Payments::StartCheckout::Invalid) { Payments::StartCheckout.call(machine: machines(:one), slot: slots(:one)) }
  end

  test "a stale paid sale does not lock the machine" do
    transactions(:one).update!(status: "paid", paid_at: nil, updated_at: 10.minutes.ago)

    assert Payments::StartCheckout.call(machine: machines(:one), slot: slots(:one)).pending?
  end

  test "marks the transaction failed when the gateway is down" do
    failing = Object.new
    def failing.create_charge(_) = raise(Payments::GatewayError, "boom")

    assert_raises(Payments::GatewayError) do
      Payments::StartCheckout.call(machine: machines(:one), slot: slots(:one), gateway: failing)
    end
    assert machines(:one).transactions.failed.where("failure_reason LIKE 'gateway_error%'").exists?
  end

  test "refuses prices below the gateway minimum with a clear message" do
    slots(:one).product.update!(price: 500)
    gateway = Payments::MockGateway.new
    def gateway.minimum_amount = 2_000

    error = assert_raises(Payments::StartCheckout::Invalid) do
      Payments::StartCheckout.call(machine: machines(:one), slot: slots(:one), gateway: gateway)
    end
    assert_equal "price is below the payment minimum of Rp 2000", error.message
  end
end
