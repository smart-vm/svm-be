class TransactionsController < ApplicationController
  def index
    @transactions = Transaction.includes(:machine, slot: :product).order(created_at: :desc).limit(100)
  end

  # Close out a sale the kiosk couldn't finish on its own.
  def resolve
    transaction = Transaction.find(params[:id])

    if transaction.resolve!(params[:outcome].to_s)
      redirect_to transactions_path, notice: "Transaction #{transaction.uuid.split('-').first} marked #{transaction.status.humanize.downcase}."
    else
      redirect_to transactions_path, alert: "That transaction is already #{transaction.status.humanize.downcase}."
    end
  rescue ArgumentError
    redirect_to transactions_path, alert: "Unknown resolution."
  end
end
