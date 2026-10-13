# Pushes `transaction_updated` events to the kiosk that owns the transaction.
class MachineTransactionChannel < ApplicationCable::Channel
  def subscribed
    return reject unless current_machine

    current_machine.touch_heartbeat!
    stream_from current_machine.transaction_stream
  end
end
