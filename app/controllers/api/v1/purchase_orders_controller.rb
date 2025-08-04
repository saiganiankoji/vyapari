class Api::V1::PurchaseOrdersController < ApplicationController
  before_action :set_purchase_order, only: [:show, :edit, :update, :destroy, :confirm, :cancel]

  # UI RENDERING ACTIONS
  def index
    @purchase_orders = PurchaseOrder.includes(:branch, purchase_order_items: :product_sku)
                                   .by_branch(params[:by_branch])
                                   .by_vendor(params[:by_vendor])
                                   .by_date_range(params[:start_date], params[:end_date])
                                   .recent
                                   .page(params[:page])
                                   .per(10)
    
    @branches = Branch.active.order(:name)
    render layout: 'application'
  end

  def show
    @purchase_order_items = @purchase_order.purchase_order_items.includes(:product_sku)
    render layout: 'application'
  end

  def new
    @purchase_order = PurchaseOrder.new
    @purchase_order.purchase_date = Date.current
    @branches = Branch.active.order(:name)
    @product_skus = ProductSku.select(:id, :sku_name, :sku_code).order(:sku_name)
    render layout: 'application'
  end

  def edit
    @branches = Branch.active.order(:name)
    @product_skus = ProductSku.select(:id, :sku_name, :sku_code).order(:sku_name)
    @purchase_order_items = @purchase_order.purchase_order_items.includes(:product_sku)
    render layout: 'application'
  end

  # API ACTIONS
  def list
    begin
      # Sanitize and validate pagination parameters
      page = [params[:page].to_i, 1].max
      per_page = sanitize_per_page(params[:per_page])
      
      purchase_orders = PurchaseOrder.includes(:branch, purchase_order_items: :product_sku)
                                    .by_branch(filter_params[:by_branch])
                                    .by_vendor(filter_params[:by_vendor])
                                    .by_date_range(filter_params[:start_date], filter_params[:end_date])
                                    .by_status(filter_params[:status])
                                    .recent
                                    .page(page)
                                    .per(per_page)
      
      render json: {
        message: "Purchase orders retrieved successfully",
        data: {
          purchase_orders: ActiveModelSerializers::SerializableResource.new(
            purchase_orders, 
            each_serializer: PurchaseOrderListingSerializer
          ).as_json,
          pagination: {
            current_page: purchase_orders.current_page,
            total_pages: purchase_orders.total_pages,
            total_count: purchase_orders.total_count,
            per_page: purchase_orders.limit_value,
            has_next_page: purchase_orders.next_page.present?,
            has_prev_page: purchase_orders.prev_page.present?
          }
        },
        errors: []
      }, status: :ok
      
    rescue StandardError => e
      Rails.logger.error "Error in purchase_orders list: #{e.message}"
      render json: {
        message: "Failed to retrieve purchase orders",
        data: {
          purchase_orders: [],
          pagination: {
            current_page: 1,
            total_pages: 0,
            total_count: 0,
            per_page: 10,
            has_next_page: false,
            has_prev_page: false
          }
        },
        errors: [e.message]
      }, status: :internal_server_error
    end
  end

  def options
    # Branch options
    branches = Branch.active.order(:name).pluck(:name, :id)
    
    # Product SKU options with search capability
    product_skus_query = ProductSku.select(:id, :sku_name, :sku_code).order(:sku_name)
    
    # Apply search filter if provided
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      product_skus_query = product_skus_query.where(
        "sku_name ILIKE ? OR sku_code ILIKE ?", 
        search_term, search_term
      )
    end
  
    # Limit to 5 results
    product_skus = product_skus_query.limit(5).map { |sku| 
      {
        id: sku.id,
        name: sku.sku_name,
        code: sku.sku_code,
        label: "#{sku.sku_name} (#{sku.sku_code})"
      }
    }
    
    render json: {
      branches: branches,
      product_skus: product_skus
    }, status: :ok
  end

  def create
    @purchase_order = PurchaseOrder.new(purchase_order_params.except(:items))
    
    ActiveRecord::Base.transaction do
      if @purchase_order.save
        # Handle items separately for better control
        if params[:purchase_order][:items].present?
          params[:purchase_order][:items].each do |item_params|
            next if item_params[:product_sku_id].blank? || item_params[:quantity].to_i <= 0
            
            @purchase_order.purchase_order_items.create!(
              product_sku_id: item_params[:product_sku_id],
              quantity: item_params[:quantity],
              unit_cost_price: item_params[:unit_cost_price]
            )
          end
        end
        
        render json: {
          message: "Purchase order created successfully",
          data: {
            purchase_order: PurchaseOrderDetailSerializer.new(@purchase_order.reload).as_json
          },
          errors: []
        }, status: :created
      else
        render json: {
          message: "Failed to create purchase order",
          data: {},
          errors: @purchase_order.errors.full_messages
        }, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      message: "Failed to create purchase order",
      data: {},
      errors: [e.message]
    }, status: :unprocessable_entity
  end

  def update
    # Prevent editing confirmed orders
    unless @purchase_order.can_be_edited?
      render json: {
        message: "Cannot edit #{@purchase_order.status} purchase order",
        data: {},
        errors: ["This purchase order is #{@purchase_order.status} and cannot be modified"]
      }, status: :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      # Update basic order details
      if @purchase_order.update(purchase_order_params.except(:items))
        # Handle items update
        handle_items_update if params[:purchase_order][:items].present?
        
        render json: {
          message: "Purchase order updated successfully",
          data: {
            purchase_order: PurchaseOrderDetailSerializer.new(@purchase_order.reload).as_json
          },
          errors: []
        }, status: :ok
      else
        render json: {
          message: "Failed to update purchase order",
          data: {},
          errors: @purchase_order.errors.full_messages
        }, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      message: "Failed to update purchase order",
      data: {},
      errors: [e.message]
    }, status: :unprocessable_entity
  end

  def destroy
    unless @purchase_order.can_be_deleted?
      render json: {
        message: "Cannot delete #{@purchase_order.status} purchase order",
        data: {},
        errors: ["This purchase order is #{@purchase_order.status} and cannot be deleted"]
      }, status: :unprocessable_entity
      return
    end

    if @purchase_order.destroy
      render json: {
        message: "Purchase order deleted successfully",
        data: {},
        errors: []
      }, status: :ok
    else
      render json: {
        message: "Failed to delete purchase order",
        data: {},
        errors: @purchase_order.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # CONFIRMATION FEATURE
  def confirm
    unless @purchase_order.can_be_confirmed?
      render json: {
        message: "Cannot confirm #{@purchase_order.status} purchase order",
        data: {},
        errors: ["This purchase order is #{@purchase_order.status} and cannot be confirmed"]
      }, status: :unprocessable_entity
      return
    end

    # Use current_user mobile number or fallback
    user_identifier = current_user&.mobile_number || "system"
    
    if @purchase_order.confirm!(user_identifier)
      render json: {
        message: "Purchase order confirmed successfully! Inventory has been updated.",
        data: {
          purchase_order: PurchaseOrderDetailSerializer.new(@purchase_order.reload).as_json
        },
        errors: []
      }, status: :ok
    else
      render json: {
        message: "Failed to confirm purchase order",
        data: {},
        errors: @purchase_order.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # CANCEL FEATURE
  def cancel
    unless @purchase_order.pending?
      render json: {
        message: "Cannot cancel #{@purchase_order.status} purchase order",
        data: {},
        errors: ["This purchase order is #{@purchase_order.status} and cannot be cancelled"]
      }, status: :unprocessable_entity
      return
    end

    # Use current_user mobile number or fallback
    user_identifier = current_user&.mobile_number || "system"
    
    if @purchase_order.cancel!(user_identifier)
      render json: {
        message: "Purchase order cancelled successfully.",
        data: {
          purchase_order: PurchaseOrderDetailSerializer.new(@purchase_order.reload).as_json
        },
        errors: []
      }, status: :ok
    else
      render json: {
        message: "Failed to cancel purchase order",
        data: {},
        errors: @purchase_order.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def set_purchase_order
    @purchase_order = PurchaseOrder.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to purchase_orders_path, alert: "Purchase order not found" }
      format.json do
        render json: {
          message: "Purchase order not found",
          data: {},
          errors: ["Purchase order with ID #{params[:id]} not found"]
        }, status: :not_found
      end
    end
  end

  def purchase_order_params
    params.require(:purchase_order).permit(
      :branch_id, :vendor_name, :vendor_address, :vendor_mobile_number,
      :vendor_gst_number, :purchase_date, :notes,
      items: [:id, :product_sku_id, :quantity, :unit_cost_price, :_destroy]
    )
  end

  def handle_items_update
    existing_item_ids = @purchase_order.purchase_order_items.pluck(:id)
    submitted_item_ids = []

    params[:purchase_order][:items].each do |item_params|
      next if item_params[:product_sku_id].blank? || item_params[:quantity].to_i <= 0

      if item_params[:id].present?
        # Update existing item
        item = @purchase_order.purchase_order_items.find(item_params[:id])
        item.update!(
          product_sku_id: item_params[:product_sku_id],
          quantity: item_params[:quantity],
          unit_cost_price: item_params[:unit_cost_price]
        )
        submitted_item_ids << item.id
      else
        # Create new item
        @purchase_order.purchase_order_items.create!(
          product_sku_id: item_params[:product_sku_id],
          quantity: item_params[:quantity],
          unit_cost_price: item_params[:unit_cost_price]
        )
      end
    end

    # Remove items that weren't in the submission
    items_to_remove = existing_item_ids - submitted_item_ids
    @purchase_order.purchase_order_items.where(id: items_to_remove).destroy_all if items_to_remove.any?
  end

  def filter_params
    # Clean up the parameters to ensure proper filtering
    cleaned_params = {}
    
    cleaned_params[:by_branch] = params[:by_branch] if params[:by_branch].present?
    cleaned_params[:by_vendor] = params[:by_vendor] if params[:by_vendor].present?
    cleaned_params[:start_date] = params[:start_date] if params[:start_date].present?
    cleaned_params[:end_date] = params[:end_date] if params[:end_date].present?
    cleaned_params[:status] = params[:status] if params[:status].present?
    
    cleaned_params
  end

  def sanitize_per_page(per_page_param)
    # Convert to integer, default to 10 if invalid
    per_page = per_page_param.to_i
    
    # Ensure it's within acceptable range
    case per_page
    when 0, nil
      10 # Default
    when 1..50
      per_page # Valid range
    else
      50 # Cap at maximum
    end
  end
end