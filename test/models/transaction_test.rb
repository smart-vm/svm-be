require "test_helper"

class TransactionTest < ActiveSupport::TestCase
  test "defaults status to pending and generates a uuid on create" do
    transaction = Transaction.create!(machine: machines(:one), slot: slots(:one), amount: 15_000)

    assert transaction.pending?
    assert transaction.uuid.present?
  end

  test "rejects a status outside the allowed enum values" do
    assert_raises(ArgumentError) do
      Transaction.new(machine: machines(:one), slot: slots(:one), amount: 1, status: "bogus")
    end
  end

  test "can transition through the enum statuses" do
    transaction = Transaction.create!(machine: machines(:one), slot: slots(:one), amount: 1)

    transaction.settled!
    assert transaction.settled?

    transaction.paid!
    assert transaction.paid?
  end

  test "uuid must be unique" do
    duplicate = Transaction.new(
      machine: machines(:one), slot: slots(:one), amount: 1, uuid: transactions(:one).uuid
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:uuid], "has already been taken"
  end
end
