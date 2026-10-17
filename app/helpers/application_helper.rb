module ApplicationHelper
  def erp_navigation_items
    [
      [ "Overview", root_path, controller_name == "dashboards" ],
      [ "Machines", machines_path, %w[machines slots].include?(controller_name) ],
      [ "Products & stock", inventories_path, controller_name == "inventories" ],
      [ "Transactions", transactions_path, controller_name == "transactions" ],
      [ "Advertisements", advertisements_path, controller_name == "advertisements" ]
    ]
  end

  def erp_shell?
    user_signed_in? && erp_navigation_items.any? { |_, _, active| active }
  end

  def erp_current_section
    erp_navigation_items.find { |_, _, active| active }&.first || "Vendora"
  end

  def erp_account_initials
    local_name = current_user.email.split("@").first
    parts = local_name.split(/[._-]+/)
    (parts.size > 1 ? parts.map(&:first).join : local_name).first(2).upcase
  end

  def erp_icon(name)
    paths = {
      "overview" => "M3 3h7v7H3z M14 3h7v7h-7z M3 14h7v7H3z M14 14h7v7h-7z",
      "machines" => "M4 3h16v7H4z M4 14h16v7H4z M7 6.5h.01 M7 17.5h.01",
      "products" => "m12 3 9 5v9l-9 5-9-5V8z M3 8l9 5 9-5 M12 13v9 M7.5 5.5l9 5V15",
      "transactions" => "M4 7h16 M4 7l4-4 M4 7l4 4 M20 17H4 M20 17l-4-4 M20 17l-4 4",
      "advertisements" => "M4 9h4l12-5v16L8 15H4z M8 15l2 6H6l-2-6 M8 9v6",
      "panel" => "M3 3h18v18H3z M9 3v18",
      "chevron" => "m6 9 6 6 6-6",
      "collapse" => "m11 7-5 5 5 5 m7-10-5 5 5 5",
      "close" => "m6 6 12 12 M6 18 18 6",
      "logout" => "M10 4H4v16h6 M14 8l4 4-4 4 M8 12h12"
    }
    tag.svg(viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", "stroke-width": 1.7,
      "stroke-linecap": "round", "stroke-linejoin": "round", class: "erp-icon", aria: { hidden: true }, focusable: false) do
      tag.path(d: paths.fetch(name))
    end
  end
end
