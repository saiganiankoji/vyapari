class Api::V1::PurchaseSkuController < ApplicationController
  before_action :set_purchase_sku, only: [:show, :update, :destroy]

  # UI RENDERING ACTIONS
  def index
    @purchase_skus = PurchaseSku.includes(:branch, :product_sku)
    
    # Apply filters manually to avoid Filterable module issues
    if params[:by_branch].present? && params[:by_branch] != 'null'
      @purchase_skus = @purchase_skus.where(branch_id: params[:by_branch])
    end
    
    if params[:by_product].present? && params[:by_product] != 'null'
      @purchase_skus = @purchase_skus.where(product_sku_id: params[:by_product])
    end
    
    if params[:by_vendor].present? && params[:by_vendor] != 'null'
      @purchase_skus = @purchase_skus.where("vendor_name ILIKE ?", "%#{params[:by_vendor]}%")
    end
    
    # Date range filtering
    if params[:start_date].present? && params[:start_date] != 'null' && params[:end_date].present? && params[:end_date] != 'null'
      @purchase_skus = @purchase_skus.where(purchase_date: params[:start_date]..params[:end_date])
    elsif params[:start_date].present? && params[:start_date] != 'null'
      @purchase_skus = @purchase_skus.where(purchase_date: params[:start_date])
    end
    
    @purchase_skus = @purchase_skus.recent.page(params[:page]).per(10)
    @branches = Branch.active.order(:name)
    @product_skus = ProductSku.order(:sku_name)
    render layout: 'application'
  end

  def show
    render layout: 'application'
  end

  def new
    @purchase_sku = PurchaseSku.new
    @branches = Branch.active.order(:name)
    @product_skus = ProductSku.order(:sku_name)
    render layout: 'application'
  end

  def edit
    @purchase_sku = PurchaseSku.find(params[:id])
    @branches = Branch.active.order(:name)
    @product_skus = ProductSku.order(:sku_name)
    render layout: 'application'
  end

  # API ACTIONS
  def list
    purchase_skus = PurchaseSku.includes(:branch, :product_sku)
    
    # Apply filters manually with better parameter checking
    if params[:by_branch].present? && params[:by_branch] != 'null'
      purchase_skus = purchase_skus.where(branch_id: params[:by_branch])
    end
    
    if params[:by_product].present? && params[:by_product] != 'null'
      purchase_skus = purchase_skus.where(product_sku_id: params[:by_product])
    end
    
    if params[:by_vendor].present? && params[:by_vendor] != 'null'
      purchase_skus = purchase_skus.where("vendor_name ILIKE ?", "%#{params[:by_vendor]}%")
    end
    
    # Date range filtering
    if params[:start_date].present? && params[:start_date] != 'null' && params[:end_date].present? && params[:end_date] != 'null'
      purchase_skus = purchase_skus.where(purchase_date: params[:start_date]..params[:end_date])
    elsif params[:start_date].present? && params[:start_date] != 'null'
      purchase_skus = purchase_skus.where(purchase_date: params[:start_date])
    end
    
    purchase_skus = purchase_skus.recent
                                 .page(params[:page] || 1)
                                 .per(params[:per_page] || 10)
    
    render json: {
      message: "Purchase records retrieved successfully",
      data: {
        purchase_skus: ActiveModelSerializers::SerializableResource.new(
          purchase_skus, 
          each_serializer: PurchaseSkuListingSerializer
        ).as_json,
        pagination: {
          current_page: purchase_skus.current_page,
          total_pages: purchase_skus.total_pages,
          total_count: purchase_skus.total_count,
          per_page: purchase_skus.limit_value
        },
        summary: {
          total_purchases: purchase_skus.count,
          total_value: purchase_skus.sum(:total_cost_price),
          this_month_value: PurchaseSku.this_month.sum(:total_cost_price),
          this_year_value: PurchaseSku.this_year.sum(:total_cost_price)
        }
      },
      errors: []
    }, status: :ok
  end

  def options
    render json: {
      branches: Branch.active.order(:name).pluck(:name, :id),
      product_skus: ProductSku.order(:sku_name).pluck(:sku_name, :id, :sku_code)
    }
  end

  def create
    @purchase_sku = PurchaseSku.new(purchase_sku_params)
    
    if @purchase_sku.save
      render json: {
        message: "Purchase record created successfully",
        data: {
          purchase_sku: PurchaseSkuListingSerializer.new(@purchase_sku).as_json
        },
        errors: []
      }, status: :created
    else
      render json: {
        message: "Failed to create purchase record",
        data: {},
        errors: @purchase_sku.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def update
    if @purchase_sku.update(purchase_sku_params)
      render json: {
        message: "Purchase record updated successfully",
        data: {
          purchase_sku: PurchaseSkuListingSerializer.new(@purchase_sku).as_json
        },
        errors: []
      }, status: :ok
    else
      render json: {
        message: "Failed to update purchase record",
        data: {},
        errors: @purchase_sku.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def destroy
    if @purchase_sku.destroy
      render json: {
        message: "Purchase record deleted successfully",
        data: {},
        errors: []
      }, status: :ok
    else
      render json: {
        message: "Failed to delete purchase record",
        data: {},
        errors: @purchase_sku.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def analytics
    render json: {
      data: {
        monthly_totals: monthly_purchase_totals,
        top_vendors: top_vendors_by_value,
        branch_wise_purchases: branch_wise_totals,
        recent_large_purchases: recent_large_purchases
      }
    }
  end

  private

  def set_purchase_sku
    @purchase_sku = PurchaseSku.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      message: "Purchase record not found",
      data: {},
      errors: ["Purchase record not found"]
    }, status: :not_found
  end

  def purchase_sku_params
    params.require(:purchase_sku).permit(
      :branch_id, :product_sku_id, :quantity, :unit_cost_price,
      :vendor_name, :vendor_address, :vendor_mobile_number, :purchase_date
    )
  end

  def filter_params
    cleaned_params = {}
    
    cleaned_params[:by_branch] = params[:by_branch] if params[:by_branch].present?
    cleaned_params[:by_product] = params[:by_product] if params[:by_product].present?
    cleaned_params[:by_vendor] = params[:by_vendor] if params[:by_vendor].present?
    
    # Handle date range - pass both dates as separate parameters
    if params[:start_date].present?
      cleaned_params[:by_date_range] = params[:start_date]
      # For now, let's handle single date filtering
      # We'll enhance this later for proper range filtering
    end
    
    cleaned_params
  end

  def monthly_purchase_totals
    PurchaseSku.where(purchase_date: 12.months.ago..Date.current)
               .group_by_month(:purchase_date)
               .sum(:total_cost_price)
  end

  def top_vendors_by_value
    PurchaseSku.group(:vendor_name)
               .sum(:total_cost_price)
               .sort_by { |_, value| -value }
               .first(5)
  end

  def branch_wise_totals
    PurchaseSku.joins(:branch)
               .group('branches.name')
               .sum(:total_cost_price)
  end

  def recent_large_purchases
    PurchaseSku.includes(:branch, :product_sku)
               .where('total_cost_price > ?', 10000)
               .recent
               .limit(5)
  end
end