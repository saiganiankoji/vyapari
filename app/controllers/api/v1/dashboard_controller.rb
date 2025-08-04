# app/controllers/api/v1/dashboard_controller.rb
class Api::V1::DashboardController < ApplicationController
  def stats
    render json: {
      stats: {
        # Branch stats
        branches: Branch.active.count,
        new_branches: Branch.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month).count,
        
        # Product stats
        skus: ProductSku.count,
        categories: ProductSku.distinct.count(:sku_name).clamp(1, 50), # Fallback for categories
        
        # Purchase Order stats
        purchase_orders: PurchaseOrder.count,
        pending_orders: PurchaseOrder.where(status: 'pending').count,
        confirmed_orders: PurchaseOrder.where(status: 'confirmed').count,
        
        # Inventory stats
        inventory_items: Inventory.count,
        low_stock_items: Inventory.where('quantity <= min_stock_level').count,
        out_of_stock_items: Inventory.where(quantity: 0).count,
        
        # Sales stats (if Sales model exists)
        sales_orders: safe_count(Sale),
        pending_sales: safe_count(Sale, status: 'pending'),
        
        # Financial stats
        total_revenue: calculate_total_revenue,
        revenue_growth: calculate_revenue_growth,
        
        # Time-based purchase analytics
        today_orders: PurchaseOrder.where(purchase_date: Date.current).count,
        today_value: PurchaseOrder.where(purchase_date: Date.current).sum(:total_amount),
        week_orders: PurchaseOrder.where(purchase_date: Date.current.beginning_of_week..Date.current.end_of_week).count,
        week_value: PurchaseOrder.where(purchase_date: Date.current.beginning_of_week..Date.current.end_of_week).sum(:total_amount),
        month_orders: PurchaseOrder.where(purchase_date: Date.current.beginning_of_month..Date.current.end_of_month).count,
        month_value: PurchaseOrder.where(purchase_date: Date.current.beginning_of_month..Date.current.end_of_month).sum(:total_amount),
        
        # Alert counts
        alerts_count: calculate_alerts_count
      }
    }
  end

  def recent_activity
    activities = []
    
    # Recent purchase orders
    recent_purchases = PurchaseOrder.includes(:branch)
                                   .order(created_at: :desc)
                                   .limit(5)
                                   .map do |order|
      {
        id: order.id,
        type: 'purchase_order',
        title: "Purchase Order #{order.po_number}",
        description: "#{order.vendor_name} - ₹#{number_with_delimiter(order.total_amount)}",
        time: time_ago_in_words(order.created_at),
        branch: order.branch_name,
        status: order.status,
        created_at: order.created_at
      }
    end

    # Recent inventory changes
    recent_inventory = []
    if defined?(InventoryTransaction)
      recent_inventory = InventoryTransaction.includes(inventory: [:branch, :product_sku])
                                            .order(created_at: :desc)
                                            .limit(5)
                                            .map do |transaction|
        {
          id: transaction.id,
          type: 'inventory_transaction',
          title: "Stock #{transaction.transaction_type.humanize}",
          description: "#{transaction.inventory.sku_name} - #{transaction.quantity_display}",
          time: time_ago_in_words(transaction.created_at),
          branch: transaction.inventory.branch_name,
          created_at: transaction.created_at
        }
      end
    end

    # Recent sales (if available)
    recent_sales = []
    if defined?(Sale)
      recent_sales = Sale.includes(:branch)
                         .order(created_at: :desc)
                         .limit(3)
                         .map do |sale|
        {
          id: sale.id,
          type: 'sale',
          title: "Sale #{sale.invoice_number}",
          description: "#{sale.customer_name} - ₹#{number_with_delimiter(sale.total_amount)}",
          time: time_ago_in_words(sale.created_at),
          branch: sale.branch_name,
          status: sale.status,
          created_at: sale.created_at
        }
      end
    end

    # Combine and sort all activities
    all_activities = (recent_purchases + recent_inventory + recent_sales)
                     .sort_by { |activity| activity[:created_at] }
                     .reverse
                     .first(10)

    render json: {
      recent_activities: all_activities,
      summary: {
        total_activities: all_activities.count,
        purchase_orders: recent_purchases.count,
        inventory_changes: recent_inventory.count,
        sales: recent_sales.count
      }
    }
  end

  def analytics_summary
    # Monthly trends for the last 6 months
    monthly_data = (0..5).map do |i|
      date = i.months.ago
      month_start = date.beginning_of_month
      month_end = date.end_of_month
      
      purchase_value = PurchaseOrder.where(purchase_date: month_start..month_end).sum(:total_amount)
      sales_value = safe_sum(Sale, :total_amount, created_at: month_start..month_end)
      
      {
        month: date.strftime("%B"),
        purchases: PurchaseOrder.where(purchase_date: month_start..month_end).count,
        purchase_value: purchase_value,
        sales: safe_count(Sale, created_at: month_start..month_end),
        sales_value: sales_value,
        profit: sales_value - purchase_value
      }
    end.reverse

    # Branch-wise performance
    branch_data = Branch.active.map do |branch|
      purchase_total = PurchaseOrder.where(branch: branch).sum(:total_amount)
      sales_total = safe_sum(Sale, :total_amount, branch: branch)
      inventory_count = Inventory.where(branch: branch).count
      
      {
        branch_name: branch.name,
        purchase_total: purchase_total,
        sales_total: sales_total,
        inventory_items: inventory_count,
        profit: sales_total - purchase_total
      }
    end

    # Top products by movement
    product_data = if defined?(Sale) && Sale.respond_to?(:joins)
      # If sales exist, show top selling products
      Sale.joins(:sale_items)
          .joins('JOIN product_skus ON sale_items.product_sku_id = product_skus.id')
          .group('product_skus.sku_name')
          .sum('sale_items.quantity')
          .sort_by { |_, quantity| -quantity }
          .first(10)
          .map { |product, quantity| { product: product, quantity: quantity, type: 'sales' } }
    else
      # Fallback to purchase data
      PurchaseOrderItem.joins(:product_sku)
                       .group('product_skus.sku_name')
                       .sum(:quantity)
                       .sort_by { |_, quantity| -quantity }
                       .first(10)
                       .map { |product, quantity| { product: product, quantity: quantity, type: 'purchases' } }
    end

    # Inventory insights
    inventory_insights = {
      total_items: Inventory.count,
      total_value: calculate_inventory_value,
      low_stock_count: Inventory.where('quantity <= min_stock_level').count,
      out_of_stock_count: Inventory.where(quantity: 0).count,
      branches_with_low_stock: Inventory.joins(:branch)
                                       .where('quantity <= min_stock_level')
                                       .group('branches.name')
                                       .count
    }

    render json: {
      monthly_trend: monthly_data,
      branch_performance: branch_data,
      top_products: product_data,
      inventory_insights: inventory_insights,
      summary: {
        total_purchase_orders: PurchaseOrder.count,
        total_purchase_value: PurchaseOrder.sum(:total_amount),
        total_sales_orders: safe_count(Sale),
        total_sales_value: safe_sum(Sale, :total_amount),
        average_order_value: PurchaseOrder.average(:total_amount) || 0,
        unique_vendors: PurchaseOrder.distinct.count(:vendor_name),
        active_branches: Branch.active.count,
        total_products: ProductSku.count
      }
    }
  end

  private

  def safe_count(model_class, conditions = {})
    return 0 unless defined?(model_class)
    model_class.where(conditions).count
  rescue
    0
  end

  def safe_sum(model_class, column, conditions = {})
    return 0 unless defined?(model_class)
    model_class.where(conditions).sum(column) || 0
  rescue
    0
  end

  def calculate_total_revenue
    # Sum of confirmed purchase orders (representing business value)
    confirmed_purchases = PurchaseOrder.where(status: 'confirmed').sum(:total_amount)
    
    # Add sales revenue if available
    sales_revenue = safe_sum(Sale, :total_amount)
    
    confirmed_purchases + sales_revenue
  end

  def calculate_revenue_growth
    current_month = Date.current.beginning_of_month..Date.current.end_of_month
    last_month = 1.month.ago.beginning_of_month..1.month.ago.end_of_month
    
    current_value = PurchaseOrder.where(purchase_date: current_month).sum(:total_amount)
    last_value = PurchaseOrder.where(purchase_date: last_month).sum(:total_amount)
    
    return 0 if last_value == 0
    ((current_value - last_value) / last_value.to_f * 100).round(1)
  end

  def calculate_alerts_count
    alerts = 0
    
    # Low stock alerts
    alerts += Inventory.where('quantity <= min_stock_level').count
    
    # Pending purchase orders
    alerts += PurchaseOrder.where(status: 'pending').count
    
    # Overdue sales (if applicable)
    if defined?(Sale)
      alerts += Sale.where('due_date < ? AND status != ?', Date.current, 'paid').count rescue 0
    end
    
    alerts
  end

  def calculate_inventory_value
    # This would require product cost information
    # For now, return a placeholder or calculate based on purchase orders
    total_inventory_items = Inventory.sum(:quantity)
    avg_cost_per_item = PurchaseOrderItem.average(:unit_cost_price) || 0
    
    (total_inventory_items * avg_cost_per_item).round(2)
  end

  def time_ago_in_words(time)
    seconds = Time.current - time
    
    case seconds
    when 0..59
      'Just now'
    when 60..3599
      "#{(seconds / 60).to_i} minutes ago"
    when 3600..86399
      "#{(seconds / 3600).to_i} hours ago"
    when 86400..604799
      "#{(seconds / 86400).to_i} days ago"
    else
      time.strftime("%b %d")
    end
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end