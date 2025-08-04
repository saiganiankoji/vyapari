class Api::V1::ProductSkuController < ApplicationController
  before_action :set_product_sku, only: [:show, :edit, :update, :destroy]

  # UI RENDERING ACTIONS
  def index
    @product_skus = ProductSku.filter(filter_params).page(params[:page]).per(10)
    render layout: 'application'
  end

  def show
    render layout: 'application'
  end

  def new
    @product_sku = ProductSku.new
    render layout: 'application'
  end

  def edit
    render layout: 'application'
  end

  # API ACTIONS
  def list
    begin
      # Sanitize and validate pagination parameters
      page = [params[:page].to_i, 1].max
      per_page = sanitize_per_page(params[:per_page])
      
      # Build query with filters
      product_skus = ProductSku.filter(filter_params)
                              .order(created_at: :desc)
                              .page(page)
                              .per(per_page)
      
      render json: {
        message: "Product SKUs retrieved successfully",
        data: {
          product_skus: ActiveModelSerializers::SerializableResource.new(
            product_skus, 
            each_serializer: ProductSkuListingSerializer
          ).as_json,
          pagination: {
            current_page: product_skus.current_page,
            total_pages: product_skus.total_pages,
            total_count: product_skus.total_count,
            per_page: product_skus.limit_value,
            has_next_page: product_skus.next_page.present?,
            has_prev_page: product_skus.prev_page.present?
          }
        },
        errors: []
      }, status: :ok
      
    rescue StandardError => e
      Rails.logger.error "Error in product_skus list: #{e.message}"
      render json: {
        message: "Failed to retrieve product SKUs",
        data: {
          product_skus: [],
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

  def create
    @product_sku = ProductSku.new(product_sku_params)
    
    if @product_sku.save
      render json: {
        message: "Product SKU created successfully",
        data: {
          product_sku: ProductSkuListingSerializer.new(@product_sku).as_json
        },
        errors: []
      }, status: :created
    else
      render json: {
        message: "Failed to create product SKU",
        data: {},
        errors: @product_sku.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def update
    if @product_sku.update(product_sku_params)
      render json: {
        message: "Product SKU updated successfully",
        data: {
          product_sku: ProductSkuListingSerializer.new(@product_sku).as_json
        },
        errors: []
      }, status: :ok
    else
      render json: {
        message: "Failed to update product SKU",
        data: {},
        errors: @product_sku.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def destroy
    if @product_sku.in_use?
      render json: {
        message: "Cannot delete product SKU as it is being used",
        data: {
          usage_summary: @product_sku.usage_summary
        },
        errors: ["Product SKU is currently in use and cannot be deleted"]
      }, status: :unprocessable_entity
    else
      @product_sku.destroy!
      render json: {
        message: "Product SKU deleted successfully",
        data: {},
        errors: []
      }, status: :ok
    end
  rescue ActiveRecord::RecordNotDestroyed => e
    render json: {
      message: "Failed to delete product SKU",
      data: {},
      errors: e.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  # Additional API endpoints
  def search_suggestions
    term = params[:term]&.strip
    limit = [params[:limit].to_i, 20].min
    limit = 10 if limit <= 0

    if term.blank?
      return render json: {
        message: "Search term is required",
        data: { suggestions: {} },
        errors: []
      }
    end

    suggestions = {
      names: ProductSku.where("sku_name ILIKE ?", "%#{term}%").limit(limit).pluck(:sku_name),
      codes: ProductSku.where("sku_code ILIKE ?", "%#{term}%").limit(limit).pluck(:sku_code)
    }

    render json: {
      message: "Search suggestions retrieved successfully",
      data: { suggestions: suggestions },
      errors: []
    }
  end

  def check_sku_code_availability
    sku_code = params[:sku_code]&.strip&.upcase
    product_sku_id = params[:product_sku_id] # For edit mode

    if sku_code.blank?
      return render json: {
        message: "SKU code is required",
        data: { available: false },
        errors: ["SKU code cannot be blank"]
      }
    end

    # Check if SKU code exists, excluding current product if editing
    query = ProductSku.where("UPPER(sku_code) = ?", sku_code)
    query = query.where.not(id: product_sku_id) if product_sku_id.present?
    
    exists = query.exists?

    render json: {
      message: exists ? "SKU code is already taken" : "SKU code is available",
      data: { 
        available: !exists,
        sku_code: sku_code
      },
      errors: []
    }
  end

  def bulk_export
    begin
      product_skus = ProductSku.filter(filter_params).order(:sku_code)
      
      csv_data = CSV.generate(headers: true) do |csv|
        csv << ['SKU Code', 'Product Name', 'Description', 'Created At']
        
        product_skus.find_each do |product|
          csv << [
            product.sku_code,
            product.sku_name,
            product.description.presence || 'N/A',
            product.created_at.strftime('%Y-%m-%d %H:%M:%S')
          ]
        end
      end

      render json: {
        message: "Export data generated successfully",
        data: {
          csv_data: csv_data,
          total_records: product_skus.count
        },
        errors: []
      }
    rescue StandardError => e
      render json: {
        message: "Failed to generate export",
        data: {},
        errors: [e.message]
      }, status: :internal_server_error
    end
  end

  private

  def set_product_sku
    @product_sku = ProductSku.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      message: "Product SKU not found",
      data: {},
      errors: ["Product SKU with ID #{params[:id]} not found"]
    }, status: :not_found
  end

  def product_sku_params
    params.require(:product_sku).permit(:sku_name, :sku_code, :description)
  end

  def filter_params
    # Clean and sanitize filter parameters
    filters = params.permit(:by_name, :by_code)
    
    # Remove empty strings and convert them to nil
    filters.each do |key, value|
      filters[key] = nil if value.blank?
    end
    
    filters
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