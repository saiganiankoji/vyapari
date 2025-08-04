# config/routes.rb - FIXED WITH PROPER API ROUTES

Rails.application.routes.draw do
  # Health checks
  get "up" => "rails/health#show", as: :rails_health_check

  # UI Routes (these remain the same for HTML rendering)
  get "/login", to: "api/v1/user#login_form", as: :login
  post "/login", to: "api/v1/user#login"
  get "/verify", to: "api/v1/user#verify_form", as: :verify
  get "/dashboard", to: "api/v1/user#dashboard", as: :dashboard
  delete "/logout", to: "api/v1/user#logout", as: :logout

  # Branch UI Routes
  get "/branches", to: "api/v1/branch#index", as: :branches
  get "/branches/new", to: "api/v1/branch#new", as: :new_branch
  get "/branches/:id", to: "api/v1/branch#show", as: :branch
  get "/branches/:id/edit", to: "api/v1/branch#edit", as: :edit_branch

  # ProductSku UI Routes
  get "/product_skus", to: "api/v1/product_sku#index", as: :product_skus
  get "/product_skus/new", to: "api/v1/product_sku#new", as: :new_product_sku
  get "/product_skus/:id/edit", to: "api/v1/product_sku#edit", as: :edit_product_sku

  # Purchase Order UI Routes
  get "/purchase_orders", to: "api/v1/purchase_orders#index", as: :purchase_orders
  get "/purchase_orders/new", to: "api/v1/purchase_orders#new", as: :new_purchase_order
  get "/purchase_orders/:id", to: "api/v1/purchase_orders#show", as: :purchase_order
  get "/purchase_orders/:id/edit", to: "api/v1/purchase_orders#edit", as: :edit_purchase_order

  # Inventory UI Routes
  get "/inventory", to: "api/v1/inventory#index", as: :inventory
  get "/inventory/:id", to: "api/v1/inventory#show", as: :inventory_item
  get "/inventory/:id/transactions", to: "api/v1/inventory#transactions", as: :inventory_transactions
  get "/inventory/:id/adjust", to: "api/v1/inventory#adjust_form", as: :adjust_inventory

  # Sales UI Routes - UPDATED TO INCLUDE ARUNA_SOLAR PREFIX FOR NAVIGATION
  get "/sales", to: "api/v1/sales#index", as: :sales
  get "/sales/new", to: "api/v1/sales#new", as: :new_sale
  get "/sales/:id", to: "api/v1/sales#show", as: :sale
  get "/sales/:id/edit", to: "api/v1/sales#edit", as: :edit_sale
  get "/sales/:id/payment", to: "api/v1/sales#payment", as: :sale_payment

  # Root route
  root to: redirect('/login')

  # API Routes - These handle JSON requests
  scope path: '/aruna_solar' do
    namespace :api do
      namespace :v1 do
        # Dashboard APIs
        get "dashboard/stats", to: "dashboard#stats"
        get "dashboard/recent_activity", to: "dashboard#recent_activity"
        get "dashboard/analytics_summary", to: "dashboard#analytics_summary"
        
        # User APIs
        post "check_user", to: "user#check_user"
        post "verify_temp_password", to: "user#verify_temp_password"
        
        # Branch APIs
        get "branches/list", to: "branch#list"
        post "branches", to: "branch#create"
        put "branches/:id", to: "branch#update"
        patch "branches/:id/toggle_status", to: "branch#toggle_status"
        
        # ProductSku APIs
        get "product_skus/list", to: "product_sku#list"
        post "product_skus", to: "product_sku#create"
        put "product_skus/:id", to: "product_sku#update"
        
        # Purchase Order APIs
        get "purchase_orders/list", to: "purchase_orders#list"
        get "purchase_orders/options", to: "purchase_orders#options"
        get "purchase_orders/analytics", to: "purchase_orders#analytics"
        post "purchase_orders", to: "purchase_orders#create"
        put "purchase_orders/:id", to: "purchase_orders#update"
        delete "purchase_orders/:id", to: "purchase_orders#destroy"
        post "purchase_orders/:id/confirm", to: "purchase_orders#confirm"
        post "purchase_orders/:id/cancel", to: "purchase_orders#cancel"
        # Purchase Order Item APIs
        post "purchase_orders/:id/add_item", to: "purchase_orders#add_item"
        put "purchase_orders/:id/update_item/:item_id", to: "purchase_orders#update_item"
        delete "purchase_orders/:id/remove_item/:item_id", to: "purchase_orders#remove_item"
        
        # Inventory APIs
        get "inventory/list", to: "inventory#list"
        get "inventory/options", to: "inventory#options"
        get "inventory/low_stock", to: "inventory#low_stock"
        get "inventory/analytics", to: "inventory#analytics"
        get "inventory/branch/:branch_id", to: "inventory#branch_inventory"
        get "inventory/:id", to: "inventory#api_show"
        get "inventory/:id/transactions", to: "inventory#api_transactions"
        post "inventory/adjust", to: "inventory#adjust"
        
        # Sales APIs - FIXED TO MATCH FRONTEND EXPECTATIONS
        get "sales/list", to: "sales#list"
        get "sales/options", to: "sales#options"
        get "sales/stock_check", to: "sales#stock_check"
        post "sales/validate_stock", to: "sales#validate_stock"
        get "sales/overdue", to: "sales#overdue"
        get "sales/analytics", to: "sales#analytics"
        get "sales/writeoff_report", to: "sales#writeoff_report"
        
        # Sales CRUD - THESE HANDLE BOTH UI AND API CALLS
        get "sales/:id", to: "sales#show"  # This handles both HTML and JSON
        get "sales/:id/financial_summary", to: "sales#financial_summary"
        post "sales", to: "sales#create"
        put "sales/:id", to: "sales#update"
        post "sales/:id/confirm", to: "sales#confirm"
        
        # Write-off and closure routes
        post "sales/:id/writeoff", to: "sales#writeoff_balance"
        post "sales/:id/close", to: "sales#close_sale"
        post "sales/:id/reopen", to: "sales#reopen_sale"
        
        # Payment APIs
        post "sales/:id/payments", to: "sales#add_payment"
        delete "sales/:id/payments/:payment_id", to: "sales#remove_payment"
      end
    end
  end
end