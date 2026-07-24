class TransactionsController < ApplicationController
  def index
    @transactions = Transaction.includes(:machine, slot: :product).order(created_at: :desc).limit(100)
  end
end
