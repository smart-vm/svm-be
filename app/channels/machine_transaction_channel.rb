class MachineTransactionChannel < ApplicationCable::Channel
  def subscribed
    # stream_from "some_channel"
    stream_from "machine_transaction_channel_#{params[:machine_uuid]}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
