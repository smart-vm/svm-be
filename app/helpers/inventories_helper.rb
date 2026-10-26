module InventoriesHelper
  def stock_batch_sell_through(batch)
    return "Not yet recorded" unless batch
    return "Stock adjusted — no sell-through time" if batch.adjusted?
    return "Sold out — start time unknown" if batch.sold_out? && batch.stocked_at.nil?
    return "Start time unknown" unless batch.stocked_at
    return "Not sold out" unless batch.sold_out?

    days, remainder = batch.sell_through_seconds.divmod(1.day.to_i)
    hours, remainder = remainder.divmod(1.hour.to_i)
    minutes, seconds = remainder.divmod(1.minute.to_i)
    if days.positive?
      "#{days}d #{hours}h #{minutes}m"
    elsif hours.positive?
      "#{hours}h #{minutes}m"
    elsif minutes.positive?
      "#{minutes}m #{seconds}s"
    else
      "#{seconds}s"
    end
  end
end
