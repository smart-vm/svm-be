class DashboardsController < ApplicationController
  def index
    today = Time.current.beginning_of_day..Time.current.end_of_day

    @total_machines = Machine.count
    @items_sold_today = Transaction.settled.where(created_at: today).count
    @today_revenue = Transaction.settled.where(created_at: today).sum(:amount)
    @low_stock_count = Slot.where("current_stock < ?", 5).count

    @recent_transactions = Transaction.includes(:machine, slot: :product).order(created_at: :desc).limit(4)
    @machines_list = Machine.order(created_at: :desc).limit(4)
  end
end
