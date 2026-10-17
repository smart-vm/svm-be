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
end
