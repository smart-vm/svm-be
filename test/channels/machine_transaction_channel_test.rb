require "test_helper"

class MachineTransactionChannelTest < ActionCable::Channel::TestCase
  test "subscribes and streams for the given machine uuid" do
    stub_connection
    subscribe(machine_uuid: "some-machine-uuid")

    assert subscription.confirmed?
    assert_has_stream "machine_transaction_channel_some-machine-uuid"
  end
end
