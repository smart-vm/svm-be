require "test_helper"

class MachineTransactionChannelTest < ActionCable::Channel::TestCase
  test "a kiosk streams its own machine's transactions" do
    machine = machines(:one)
    stub_connection current_machine: machine, current_user: nil

    subscribe

    assert subscription.confirmed?
    assert_has_stream "machine_transaction_channel_#{machine.uuid}"
  end

  test "a connection without a machine is rejected" do
    stub_connection current_machine: nil, current_user: users(:one)

    subscribe(machine_uuid: machines(:one).uuid)

    assert subscription.rejected?
  end
end

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "connects with a machine token" do
    connect headers: { "Authorization" => "Bearer #{machines(:one).api_token}" }

    assert_equal machines(:one), connection.current_machine
  end

  test "rejects an unknown token" do
    assert_reject_connection { connect headers: { "Authorization" => "Bearer nope" } }
  end
end
