require "csv"

class TransactionsController < ApplicationController
  PAGE_SIZE = 50

  def index
    @query = params[:q].to_s.strip.first(100)
    @status = params[:status].to_s if Transaction::STATUSES.include?(params[:status].to_s)
    scope = Transaction.all
    scope = scope.where(status: @status) if @status.present?
    if @query.present?
      pattern = "%#{Transaction.sanitize_sql_like(@query)}%"
      scope = scope.left_joins(:machine, slot: :product).where(
        "transactions.uuid::text ILIKE :q OR machines.location_name ILIKE :q OR products.name ILIKE :q", q: pattern
      )
    end

    @total_count = scope.count
    @total_pages = [ (@total_count.to_f / PAGE_SIZE).ceil, 1 ].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    @transactions = scope.includes(:machine, slot: :product).order(created_at: :desc, id: :desc)
      .offset((@page - 1) * PAGE_SIZE).limit(PAGE_SIZE)

    respond_to do |format|
      format.html
      format.csv do
        csv = CSV.generate do |rows|
          rows << [ "Created at (UTC)", "Transaction ID", "Location", "Product", "Amount (IDR)", "Status" ]
          @transactions.each do |transaction|
            rows << [ transaction.created_at.utc.iso8601, transaction.uuid,
              safe_csv_text(transaction.machine.location_name), safe_csv_text(transaction.slot&.product&.name),
              transaction.amount&.to_s("F"), transaction.status ]
          end
        end
        send_data csv, filename: "vendora-transactions-page-#{@page}.csv", type: "text/csv; charset=utf-8"
      end
    end
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

  private

  # Keep operator-controlled names from being interpreted as spreadsheet formulas.
  def safe_csv_text(value)
    text = value.to_s
    text.match?(/\A(?:[=+\-@\t\r]|\s+[=+\-@])/) ? "'#{text}" : text
  end
end
