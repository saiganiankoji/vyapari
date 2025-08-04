# app/controllers/api/v1/inventory_controller.rb
class Api::V1::InventoryController < ApplicationController
  before_action :set_inventory, only: [:show, :transactions]

  # UI RENDERING ACTIONS
  def index
    @inventories = Inventory.includes(:branch, :product_sku)
                           .by_branch(params[:branch_id])
                           .page(params[:page])
                           .per(20)
    
    @branches = Branch.active.order(:name)
    render layout: 'application'
  end

  def show
    @inventory_transactions = @inventory.inventory_transactions
                                       .includes(:source)
                                       .recent
                                       .page(params[:page])
                                       .per(20)
    render layout: 'application'
  end

  def transactions
    @inventory_transactions = @inventory.inventory_transactions
                                     .includes(:source)
                                     .recent
                                     .page(params[:page])
                                     .per(20)
    render 'api/v1/inventory/transactions', layout: 'application'
  end

  def adjust_form
    @inventory = Inventory.find(params[:id])
    render layout: 'application'
  end

  # API ACTIONS
  # GET /aruna_solar/api/v1/inventory/list
  def list
    inventories = Inventory.includes(:branch, :product_sku)
                          .by_branch(params[:branch_id])
                          .page(params[:page] || 1)
                          .per(params[:per_page] || 20)

    # Apply search filter
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      inventories = inventories.joins(:product_sku)
                              .where("product_skus.sku_name ILIKE ? OR product_skus.sku_code ILIKE ?", 
                                     search_term, search_term)
    end

    # Apply stock filter
    case params[:stock_filter]
    when 'in_stock'
      inventories = inventories.where('quantity > min_stock_level')
    when 'low_stock'
      inventories = inventories.where('quantity > 0 AND quantity <= min_stock_level')
    when 'out_of_stock'
      inventories = inventories.where(quantity: 0)
    end

    render json: {
      message: "Inventory data retrieved successfully",
      data: {
        inventories: inventories.map do |inventory|
          {
            id: inventory.id,
            branch_id: inventory.branch_id,
            branch_name: inventory.branch_name,
            product_sku_id: inventory.product_sku_id,
            sku_name: inventory.sku_name,
            sku_code: inventory.sku_code,
            quantity: inventory.quantity,
            min_stock_level: inventory.min_stock_level,
            last_updated_at: inventory.last_updated_at&.strftime("%d %b %Y %I:%M %p"),
            stock_status: inventory.stock_status
          }
        end,
        pagination: {
          current_page: inventories.current_page,
          total_pages: inventories.total_pages,
          total_count: inventories.total_count,
          per_page: inventories.limit_value
        }
      },
      errors: []
    }, status: :ok
  end

  # GET /aruna_solar/api/v1/inventory/options
  def options
    render json: {
      branches: Branch.active.order(:name).map { |branch|
        {
          id: branch.id,
          name: branch.name
        }
      }
    }, status: :ok
  end

  # GET /aruna_solar/api/v1/inventory/low_stock - UPDATED
  def low_stock
    # Changed condition to show items with quantity <= 10
    low_stock_items = Inventory.includes(:branch, :product_sku)
                              .where('quantity <= ?', 10)
                              .order(:quantity)

    render json: {
      message: "Low stock items retrieved successfully",
      data: {
        low_stock_items: low_stock_items.map do |inventory|
          {
            id: inventory.id,
            branch_name: inventory.branch_name,
            sku_name: inventory.sku_name,
            sku_code: inventory.sku_code,
            quantity: inventory.quantity,
            min_stock_level: inventory.min_stock_level,
            shortage: [10 - inventory.quantity, 0].max, # Calculate shortage from 10
            urgency: inventory.quantity == 0 ? 'critical' : (inventory.quantity <= 5 ? 'high' : 'medium')
          }
        end,
        total_count: low_stock_items.count
      },
      errors: []
    }, status: :ok
  end

  # POST /aruna_solar/api/v1/inventory/adjust
  def adjust
    inventory = Inventory.find(params[:inventory_id])
    
    case params[:adjustment_type]
    when 'add'
      success = inventory.add_stock(
        params[:quantity].to_i,
        source: nil,
        notes: params[:notes]
      )
      message = "Stock added successfully"
    when 'remove'
      success = inventory.remove_stock(
        params[:quantity].to_i,
        source: nil,
        notes: params[:notes]
      )
      message = "Stock removed successfully"
    when 'set'
      success = inventory.adjust_stock(
        params[:quantity].to_i,
        source: nil,
        notes: params[:notes]
      )
      message = "Stock adjusted successfully"
    else
      return render json: {
        message: "Invalid adjustment type",
        data: {},
        errors: ["Invalid adjustment type"]
      }, status: :unprocessable_entity
    end

    if success
      render json: {
        message: message,
        data: {
          inventory: {
            id: inventory.id,
            quantity: inventory.quantity,
            stock_status: inventory.stock_status
          }
        },
        errors: []
      }, status: :ok
    else
      render json: {
        message: "Failed to adjust inventory",
        data: {},
        errors: inventory.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: {
      message: "Inventory item not found",
      data: {},
      errors: ["Inventory item not found"]
    }, status: :not_found
  end

  # GET /aruna_solar/api/v1/inventory/analytics
  def analytics
    render json: {
      message: "Inventory analytics retrieved successfully",
      data: {
        summary: {
          total_items: Inventory.count,
          total_value: calculate_total_inventory_value,
          in_stock_items: Inventory.where('quantity > min_stock_level').count,
          low_stock_items: Inventory.where('quantity > 0 AND quantity <= min_stock_level').count,
          out_of_stock_items: Inventory.where(quantity: 0).count,
          critical_low_stock: Inventory.where('quantity <= ?', 10).count, # Added new metric
          avg_stock_level: Inventory.average(:quantity)&.round(2) || 0
        },
        branch_wise_stock: branch_wise_stock_levels,
        top_products_by_value: top_products_by_value,
        stock_movement_trends: stock_movement_trends,
        reorder_alerts: reorder_alerts
      },
      errors: []
    }, status: :ok
  end

  # GET /aruna_solar/api/v1/inventory/:id (API)
  def api_show
    inventory = Inventory.includes(:branch, :product_sku).find(params[:id])
    
    render json: {
      message: "Inventory item retrieved successfully",
      data: {
        inventory: {
          id: inventory.id,
          branch_name: inventory.branch_name,
          sku_name: inventory.sku_name,
          sku_code: inventory.sku_code,
          quantity: inventory.quantity,
          min_stock_level: inventory.min_stock_level,
          last_updated_at: inventory.last_updated_at&.strftime("%d %b %Y %I:%M %p"),
          stock_status: inventory.stock_status,
          created_at: inventory.created_at&.strftime("%d %b %Y"),
          updated_at: inventory.updated_at&.strftime("%d %b %Y %I:%M %p")
        }
      },
      errors: []
    }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: {
      message: "Inventory item not found",
      data: {},
      errors: ["Inventory item not found"]
    }, status: :not_found
  end

  # GET /aruna_solar/api/v1/inventory/:id/transactions (API)
  def api_transactions
    inventory = Inventory.find(params[:id])
    transactions = inventory.inventory_transactions
                           .includes(:source)
                           .recent
                           .page(params[:page] || 1)
                           .per(params[:per_page] || 20)

    render json: {
      message: "Inventory transactions retrieved successfully",
      data: {
        inventory: {
          id: inventory.id,
          branch_name: inventory.branch_name,
          sku_name: inventory.sku_name,
          sku_code: inventory.sku_code,
          current_quantity: inventory.quantity
        },
        transactions: transactions.map do |transaction|
          {
            id: transaction.id,
            transaction_type: transaction.transaction_type_display,
            quantity: transaction.quantity,
            quantity_display: transaction.quantity_display,
            balance_after: transaction.balance_after,
            source_info: transaction.source_info,
            notes: transaction.notes,
            created_at: transaction.formatted_created_at
          }
        end,
        pagination: {
          current_page: transactions.current_page,
          total_pages: transactions.total_pages,
          total_count: transactions.total_count,
          per_page: transactions.limit_value
        }
      },
      errors: []
    }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: {
      message: "Inventory item not found",
      data: {},
      errors: ["Inventory item not found"]
    }, status: :not_found
  end

  def branch_inventory
    branch = Branch.find(params[:branch_id])
    inventory_items = Inventory.includes(:product_sku)
                              .where(branch_id: params[:branch_id])
                              .order('product_skus.sku_name')

    render json: {
      branch: {
        id: branch.id,
        name: branch.name
      },
      inventory: inventory_items.map do |item|
        {
          id: item.id,
          product_sku_id: item.product_sku_id,
          product_sku_name: item.product_sku.sku_name,
          product_sku_code: item.product_sku.sku_code,
          quantity: item.quantity,
          min_stock_level: item.min_stock_level,
          stock_status: item.stock_status,
          last_updated_at: item.last_updated_at&.strftime('%d %b %Y %I:%M %p')
        }
      end
    }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      errors: ["Branch not found"]
    }, status: :not_found
  end

  private

  def set_inventory
    @inventory = Inventory.includes(:branch, :product_sku).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to inventory_path, alert: "Inventory item not found" }
      format.json do
        render json: {
          message: "Inventory item not found",
          data: {},
          errors: ["Inventory item with ID #{params[:id]} not found"]
        }, status: :not_found
      end
    end
  end

  def calculate_total_inventory_value
    # This would require product cost information
    # For now, return 0 or implement based on your product pricing
    0
  end

  def branch_wise_stock_levels
    Inventory.joins(:branch)
             .group('branches.name')
             .sum(:quantity)
             .map { |branch, quantity| 
               { branch: branch, total_quantity: quantity }
             }
  end

  def top_products_by_value
    # This would require product pricing
    # For now, show top products by quantity
    Inventory.joins(:product_sku)
             .group('product_skus.sku_name')
             .sum(:quantity)
             .sort_by { |_, quantity| -quantity }
             .first(10)
             .map { |product, quantity| 
               { product: product, quantity: quantity }
             }
  end

  def stock_movement_trends
    # Get stock movements for the last 12 months
    monthly_data = {}
    
    (0..11).each do |i|
      date = i.months.ago
      month_key = date.strftime("%b %Y")
      start_date = date.beginning_of_month
      end_date = date.end_of_month
      
      purchases = InventoryTransaction.where(
        transaction_type: 'purchase',
        created_at: start_date..end_date
      ).sum(:quantity)
      
      sales = InventoryTransaction.where(
        transaction_type: 'sale',
        created_at: start_date..end_date
      ).sum(:quantity).abs
      
      monthly_data[month_key] = {
        purchases: purchases,
        sales: sales,
        net_change: purchases - sales
      }
    end
    
    monthly_data.reverse_each.to_h
  end

  def reorder_alerts
    # Updated to show items with quantity <= 10
    Inventory.includes(:branch, :product_sku)
             .where('quantity <= ?', 10)
             .order(:quantity)
             .limit(20)
             .map do |inventory|
      {
        id: inventory.id,
        branch_name: inventory.branch_name,
        sku_name: inventory.sku_name,
        sku_code: inventory.sku_code,
        current_quantity: inventory.quantity,
        min_stock_level: inventory.min_stock_level,
        shortage: [10 - inventory.quantity, 0].max,
        urgency: inventory.quantity == 0 ? 'critical' : (inventory.quantity <= 5 ? 'high' : 'medium')
      }
    end
  end
end