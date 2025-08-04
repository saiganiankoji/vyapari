# app/controllers/api/v1/sales_controller.rb - FIXED WITH INVENTORY VALIDATION

class Api::V1::SalesController < ApplicationController
  before_action :set_sale, only: [:show, :edit, :update, :confirm, :payment, :add_payment, :remove_payment]

  # UI RENDERING ACTIONS
  def index
    @branches = Branch.active.order(:name)
    render layout: 'application'
  end

  def new
    @sale = Sale.new
    @sale.sale_items.build
    @branches = Branch.active.order(:name)
    @product_skus = ProductSku.order(:sku_name)
    render layout: 'application'
  end

  def show
    @sale = Sale.includes(:branch, :sale_items, :payments, sale_items: :product_sku).find(params[:id])
  
    respond_to do |format|
      format.html { render layout: 'application' }
      format.json { 
        render json: {
          id: @sale.id,
          invoice_number: @sale.invoice_number,
          customer_name: @sale.customer_name,
          customer_phone: @sale.customer_phone,
          customer_address: @sale.customer_address,
          customer_gst_number: @sale.customer_gst_number,
          branch_id: @sale.branch_id,
          branch_name: @sale.branch&.name,
          sale_date: @sale.sale_date&.strftime('%Y-%m-%d'),
          due_date: @sale.due_date&.strftime('%Y-%m-%d'),
          formatted_sale_date: @sale.sale_date&.strftime('%d/%m/%Y'),
          formatted_due_date: @sale.due_date&.strftime('%d/%m/%Y'),
          notes: @sale.notes,
          discount_amount: @sale.discount_amount || 0,
          total_amount: @sale.total_amount || 0,
          final_amount: @sale.final_amount || 0,
          paid_amount: @sale.paid_amount || 0,
          due_amount: @sale.due_amount || 0,
          
          # NEW: Write-off fields
          writeoff_amount: @sale.writeoff_amount || 0,
          writeoff_reason: @sale.writeoff_reason,
          writeoff_date: @sale.writeoff_date&.strftime('%d/%m/%Y'),
          writeoff_by: @sale.writeoff_by,
          is_closed: @sale.is_closed || false,
          closed_date: @sale.closed_date&.strftime('%d/%m/%Y'),
          closure_notes: @sale.closure_notes,
          closure_status: @sale.closure_status,
          
          # NEW: Calculated fields
          collection_efficiency: @sale.collection_efficiency,
          recovery_rate: @sale.recovery_rate,
          writeoff_percentage: @sale.effective_loss_percentage,
          
          sale_status: @sale.sale_status,
          payment_status: @sale.payment_status_with_writeoff, # Updated method
          is_overdue: @sale.overdue?,
          days_overdue: @sale.days_overdue,
          can_edit: @sale.can_edit?,
          can_confirm: @sale.can_confirm?,
          can_add_payments: @sale.can_add_payments?,
          can_writeoff: @sale.can_writeoff?, # NEW
          
          sale_items: @sale.sale_items.includes(:product_sku).map do |item|
            {
              id: item.id,
              product_sku_id: item.product_sku_id,
              product_sku_name: item.product_sku&.sku_name,
              product_sku_code: item.product_sku&.sku_code,
              quantity: item.quantity,
              unit_price: item.unit_price,
              discount_percentage: item.discount_percentage || 0,
              discount_amount: item.discount_amount || 0,
              total_price: item.total_price || 0
            }
          end,
          payments: @sale.payments.map do |payment|
            {
              id: payment.id,
              amount: payment.amount,
              payment_date: payment.payment_date,
              formatted_payment_date: payment.payment_date&.strftime('%d/%m/%Y'),
              payment_mode: payment.payment_mode,
              reference_number: payment.reference_number,
              notes: payment.notes
            }
          end
        }
      }
    end
  end

  def edit
    if @sale.sale_status != 0 && @sale.sale_status != 'draft'
      redirect_to sale_path(@sale), alert: "Cannot edit confirmed sale. You can only add payments."
      return
    end
    
    @branches = Branch.active.order(:name)
    @product_skus = ProductSku.order(:sku_name)
    render layout: 'application'
  end

  def payment
    unless @sale.can_add_payments?
      redirect_to @sale, alert: "Please confirm the sale first before adding payments."
      return
    end
    
    @payment_modes = ['cash', 'card', 'upi', 'bank_transfer', 'cheque']
    render layout: 'application'
  end

  def list
    sales = Sale.includes(:branch, :payments)
    
    # Apply filters
    sales = sales.joins(:branch).where(branches: { id: params[:branch_id] }) if params[:branch_id].present?
    sales = sales.where("customer_name ILIKE ?", "%#{params[:customer]}%") if params[:customer].present?
    
    # Payment status filter - UPDATED WITH WRITE-OFF LOGIC
    case params[:status]
    when 'completed'
      sales = sales.where('due_amount <= 0')
    when 'partial'
      sales = sales.where('paid_amount > 0 AND due_amount > 0')
    when 'pending'
      sales = sales.where('(paid_amount = 0 OR paid_amount IS NULL) AND due_amount > 0')
    when 'overdue'
      sales = sales.where('due_amount > 0 AND due_date < ? AND is_closed = false', Date.current)
    when 'closed'  # NEW FILTER
      sales = sales.where(is_closed: true)
    when 'writeoff'  # NEW FILTER  
      sales = sales.where('writeoff_amount > 0')
    end
    
    # Sale status filter
    sales = sales.where(sale_status: params[:sale_status]) if params[:sale_status].present?
    
    # Date range filter
    if params[:start_date].present? && params[:end_date].present?
      sales = sales.where(sale_date: params[:start_date]..params[:end_date])
    end

    sales = sales.order(sale_date: :desc, created_at: :desc)
                .page(params[:page] || 1)
                .per(params[:per_page] || 20)

    render json: {
      message: "Sales data retrieved successfully",
      data: {
        sales: sales.map do |sale|
          {
            id: sale.id,
            invoice_number: sale.invoice_number,
            customer_name: sale.customer_name,
            customer_phone: sale.customer_phone,
            branch_name: sale.branch&.name,
            sale_date: sale.sale_date&.strftime('%d/%m/%Y'),
            due_date: sale.due_date&.strftime('%d/%m/%Y'),
            final_amount: sale.final_amount || 0,
            paid_amount: sale.paid_amount || 0,
            due_amount: sale.due_amount || 0,
            writeoff_amount: sale.writeoff_amount || 0,  # NEW
            sale_status: sale.sale_status,
            payment_status: sale.payment_status_with_writeoff,  # UPDATED METHOD
            is_overdue: sale.overdue?,
            days_overdue: sale.days_overdue,
            is_closed: sale.is_closed?,  # NEW
            closure_status: sale.closure_status,  # NEW
            collection_efficiency: sale.collection_efficiency,  # NEW
            recovery_rate: sale.recovery_rate,  # NEW
            can_edit: sale.can_edit?,
            can_confirm: sale.can_confirm?,
            can_add_payments: sale.can_add_payments?,
            can_writeoff: sale.can_writeoff?  # NEW
          }
        end,
        pagination: {
          current_page: sales.current_page,
          total_pages: sales.total_pages,
          total_count: sales.total_count,
          per_page: sales.limit_value
        },
        summary: {  # NEW - Add summary statistics
          total_sales_value: sales.sum(:final_amount),
          total_collected: sales.sum(:paid_amount),
          total_writeoffs: sales.sum(:writeoff_amount),
          total_outstanding: sales.sum(:due_amount),
          average_collection_efficiency: calculate_average_collection_efficiency(sales)
        }
      },
      errors: []
    }, status: :ok
  end

  # GET /sales/options - Get options for dropdowns
  def options
    branch_id = params[:branch_id]
    search_query = params[:search]
    
    # If branch_id is provided, get only products available in that branch
    if branch_id.present?
      query = ProductSku.joins(:inventories)
                       .where(inventories: { branch_id: branch_id })
                       .where('inventories.quantity >= 0')
                       .select('product_skus.*, inventories.quantity as available_stock')
                       .order(:sku_name)
      
      # Add search filter if provided
      if search_query.present?
        search_term = "%#{search_query}%"
        query = query.where("product_skus.sku_name ILIKE ? OR product_skus.sku_code ILIKE ?", 
                           search_term, search_term)
      end
      
      # Limit to 5 results for dropdown
      product_skus = query.limit(5)
    else
      product_skus = ProductSku.order(:sku_name).limit(5)
    end

    render json: {
      branches: Branch.active.order(:name).map { |branch|
        {
          id: branch.id,
          name: branch.name
        }
      },
      product_skus: product_skus.map { |sku|
        stock_info = branch_id.present? && sku.respond_to?(:available_stock) ? " (#{sku.available_stock} available)" : ""
        {
          id: sku.id,
          name: sku.sku_name,
          code: sku.sku_code,
          display_name: "#{sku.sku_name} - #{sku.sku_code}#{stock_info}",
          available_stock: branch_id.present? ? (sku.respond_to?(:available_stock) ? sku.available_stock : 0) : nil
        }
      },
      payment_modes: [
        { value: 'cash', label: 'Cash' },
        { value: 'card', label: 'Card' },
        { value: 'upi', label: 'UPI' },
        { value: 'bank_transfer', label: 'Bank Transfer' },
        { value: 'cheque', label: 'Cheque' }
      ]
    }, status: :ok
  end

  # NEW METHOD - Validate stock before saving
  def validate_stock
    branch_id = params[:branch_id]
    sale_items = params[:sale_items] || []
    
    validation_errors = []
    
    sale_items.each_with_index do |item, index|
      next if item[:_destroy] == true || item[:product_sku_id].blank?
      
      inventory = Inventory.find_by(
        branch_id: branch_id,
        product_sku_id: item[:product_sku_id]
      )
      
      unless inventory
        product = ProductSku.find_by(id: item[:product_sku_id])
        validation_errors << "Product '#{product&.sku_name}' is not available in this branch"
        next
      end
      
      requested_quantity = item[:quantity].to_i
      available_stock = inventory.quantity
      
      if requested_quantity > available_stock
        validation_errors << "Product '#{inventory.sku_name}': Only #{available_stock} units available, but #{requested_quantity} requested"
      end
    end
    
    render json: {
      valid: validation_errors.empty?,
      errors: validation_errors
    }
  end

  def stock_check
    branch_id = params[:branch_id]
    product_sku_id = params[:product_sku_id]
    
    if branch_id.present? && product_sku_id.present?
      inventory = Inventory.find_by(branch_id: branch_id, product_sku_id: product_sku_id)
      available_stock = inventory&.quantity || 0
      
      render json: {
        available_stock: available_stock,
        product_name: inventory&.product_sku&.sku_name,
        has_stock: available_stock > 0
      }
    else
      render json: { available_stock: 0, has_stock: false }
    end
  end

  def overdue
    overdue_sales = Sale.includes(:branch)
                       .where('due_amount > 0 AND due_date < ?', Date.current)
                       .order(:due_date)
                       .limit(50)
    
    render json: {
      overdue_sales: overdue_sales.map do |sale|
        {
          id: sale.id,
          invoice_number: sale.invoice_number,
          customer_name: sale.customer_name,
          customer_phone: sale.customer_phone,
          branch_name: sale.branch&.name,
          due_amount: sale.due_amount,
          due_date: sale.due_date&.strftime('%d/%m/%Y'),
          days_overdue: (Date.current - sale.due_date).to_i
        }
      end
    }, status: :ok
  end

  def analytics
    branch_id = params[:branch_id]
    start_date = params[:start_date]&.to_date || 30.days.ago.to_date
    end_date = params[:end_date]&.to_date || Date.current

    sales_query = Sale.where(sale_date: start_date..end_date)
    sales_query = sales_query.where(branch_id: branch_id) if branch_id.present?

    render json: {
      total_sales: sales_query.sum(:final_amount),
      total_sales_count: sales_query.count,
      total_paid: sales_query.sum(:paid_amount),
      total_due: sales_query.sum(:due_amount),
      overdue_amount: sales_query.joins(:branch).where('due_amount > 0 AND due_date < ?', Date.current).sum(:due_amount),
      payment_status_breakdown: payment_status_breakdown(sales_query),
      daily_sales: sales_query.group(:sale_date).sum(:final_amount),
      payment_distribution: payment_mode_distribution(sales_query)
    }, status: :ok
  end

  def create
    # First validate stock before creating
    validation_result = validate_sale_stock(sale_params)
    
    unless validation_result[:valid]
      return render json: {
        success: false,
        errors: validation_result[:errors]
      }, status: :unprocessable_entity
    end
    
    @sale = Sale.new(sale_params)
    
    if @sale.save
      render json: {
        success: true,
        message: "Sale created as draft. Review and confirm to deduct inventory.",
        sale: {
          id: @sale.id,
          invoice_number: @sale.invoice_number,
          sale_status: @sale.sale_status,
          can_confirm: @sale.can_confirm?
        },
        redirect_to_confirmation: true
      }, status: :created
    else
      render json: {
        success: false,
        errors: @sale.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def update
    unless @sale.can_edit?
      render json: {
        success: false,
        errors: ["Cannot edit confirmed sale"],
        can_edit: false,
        sale_status: @sale.sale_status
      }, status: :forbidden
      return
    end

    # Debug: Log the incoming parameters
    Rails.logger.info "Sale Update - Incoming sale_params: #{sale_params.inspect}"
    
    # Validate stock before updating
    validation_result = validate_sale_stock(sale_params)
    
    unless validation_result[:valid]
      return render json: {
        success: false,
        errors: validation_result[:errors]
      }, status: :unprocessable_entity
    end

    if @sale.update(sale_params)
      render json: {
        success: true,
        message: "Sale updated successfully.",
        sale: {
          id: @sale.id,
          invoice_number: @sale.invoice_number,
          can_confirm: @sale.can_confirm?
        },
        redirect_to_confirmation: true
      }, status: :ok
    else
      Rails.logger.error "Sale Update Error: #{@sale.errors.full_messages}"
      render json: {
        success: false,
        errors: @sale.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def confirm
    if @sale.confirm_sale!
      render json: {
        success: true,
        message: "Sale confirmed successfully! Inventory has been deducted. You can now record payments.",
        sale: {
          id: @sale.id,
          invoice_number: @sale.invoice_number,
          sale_status: @sale.sale_status,
          can_edit: @sale.can_edit?,
          can_add_payments: @sale.can_add_payments?
        }
      }, status: :ok
    else
      render json: {
        success: false,
        errors: @sale.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def add_payment
    unless @sale.can_add_payments?
      render json: {
        success: false,
        errors: ["Please confirm the sale first before adding payments"]
      }, status: :forbidden
      return
    end

    payment_params = params.permit(:amount, :payment_date, :payment_mode, :reference_number, :notes)
    
    payment = @sale.add_payment(
      payment_params[:amount].to_f,
      {
        payment_date: payment_params[:payment_date]&.to_date,
        payment_mode: payment_params[:payment_mode],
        reference_number: payment_params[:reference_number],
        notes: payment_params[:notes]
      }
    )

    if payment && payment.persisted?
      render json: {
        success: true,
        message: "Payment added successfully",
        payment: {
          id: payment.id,
          amount: payment.amount,
          payment_date: payment.payment_date&.strftime('%d/%m/%Y'),
          payment_mode: payment.payment_mode
        },
        sale: {
          paid_amount: @sale.reload.paid_amount,
          due_amount: @sale.due_amount,
          payment_status: determine_payment_status(@sale)
        }
      }, status: :created
    else
      render json: {
        success: false,
        errors: @sale.errors.full_messages.presence || ["Invalid payment amount or payment exceeds due amount"]
      }, status: :unprocessable_entity
    end
  end

  def remove_payment
    payment = @sale.payments.find(params[:payment_id])
    
    if payment.destroy
      render json: {
        success: true,
        message: "Payment removed successfully",
        sale: {
          paid_amount: @sale.reload.paid_amount,
          due_amount: @sale.due_amount,
          payment_status: determine_payment_status(@sale)
        }
      }, status: :ok
    else
      render json: {
        success: false,
        errors: ["Unable to remove payment"]
      }, status: :unprocessable_entity
    end
  end

# POST /aruna_solar/api/v1/sales/:id/writeoff
def writeoff_balance
  unless @sale.can_writeoff?
    render json: {
      success: false,
      errors: ["Cannot write off this sale. Sale must be confirmed, have due amount, and be open."]
    }, status: :unprocessable_entity
    return
  end

  writeoff_params = params.permit(:writeoff_type, :amount, :reason, :authorized_by, :notes)
  
  # Validate required fields
  if writeoff_params[:reason].blank? || writeoff_params[:authorized_by].blank?
    render json: {
      success: false,
      errors: ["Reason and authorized person name are required fields"]
    }, status: :unprocessable_entity
    return
  end
  
  # Get current user info (you can adjust this based on your authentication)
  current_user_name = writeoff_params[:authorized_by] # From form
  current_user_id = session[:current_user_id] || 'system' # From session if available
  
  success = case writeoff_params[:writeoff_type]
  when 'full'
    @sale.writeoff_remaining_balance!(
      reason: writeoff_params[:reason],
      authorized_by: "#{current_user_name} (ID: #{current_user_id})",
      notes: writeoff_params[:notes] || "Full write-off processed on #{Date.current.strftime('%d/%m/%Y')}"
    )
  when 'partial'
    amount = writeoff_params[:amount].to_f
    if amount <= 0 || amount > @sale.due_amount
      render json: {
        success: false,
        errors: ["Invalid amount. Must be between ₹0.01 and ₹#{@sale.due_amount}"]
      }, status: :unprocessable_entity
      return
    end
    
    @sale.partial_writeoff!(
      amount: amount,
      reason: writeoff_params[:reason],
      authorized_by: "#{current_user_name} (ID: #{current_user_id})",
      notes: writeoff_params[:notes] || "Partial write-off of ₹#{amount} processed on #{Date.current.strftime('%d/%m/%Y')}"
    )
  else
    false
  end

  if success
    # Log the write-off activity
    Rails.logger.info "WRITE-OFF: Sale #{@sale.invoice_number} - #{writeoff_params[:writeoff_type]} write-off of ₹#{writeoff_params[:writeoff_type] == 'full' ? @sale.writeoff_amount : writeoff_params[:amount]} by #{current_user_name}"
    
    render json: {
      success: true,
      message: "Write-off processed successfully",
      sale: {
        id: @sale.id,
        invoice_number: @sale.invoice_number,
        due_amount: @sale.due_amount,
        writeoff_amount: @sale.writeoff_amount,
        is_closed: @sale.is_closed?,
        payment_status: @sale.payment_status_with_writeoff,
        collection_efficiency: @sale.collection_efficiency,
        recovery_rate: @sale.recovery_rate,
        writeoff_percentage: @sale.effective_loss_percentage,
        financial_summary: @sale.financial_summary
      }
    }, status: :ok
  else
    render json: {
      success: false,
      errors: @sale.errors.full_messages
    }, status: :unprocessable_entity
  end
end

# POST /aruna_solar/api/v1/sales/:id/close
def close_sale
  close_params = params.permit(:reason, :authorized_by, :notes)
  
  if close_params[:reason].blank? || close_params[:authorized_by].blank?
    render json: {
      success: false,
      errors: ["Reason and authorized person name are required"]
    }, status: :unprocessable_entity
    return
  end
  
  # Get current user info
  current_user_name = close_params[:authorized_by]
  current_user_id = session[:current_user_id] || 'system'
  
  if @sale.close_sale!(
    reason: close_params[:reason],
    authorized_by: "#{current_user_name} (ID: #{current_user_id})",
    notes: close_params[:notes] || "Sale closed on #{Date.current.strftime('%d/%m/%Y')}"
  )
    # Log the closure activity
    Rails.logger.info "SALE CLOSURE: Sale #{@sale.invoice_number} closed by #{current_user_name}. Reason: #{close_params[:reason]}"
    
    render json: {
      success: true,
      message: "Sale closed successfully",
      sale: {
        id: @sale.id,
        invoice_number: @sale.invoice_number,
        is_closed: @sale.is_closed?,
        closure_status: @sale.closure_status,
        financial_summary: @sale.financial_summary
      }
    }, status: :ok
  else
    render json: {
      success: false,
      errors: @sale.errors.full_messages
    }, status: :unprocessable_entity
  end
end

# POST /aruna_solar/api/v1/sales/:id/reopen
def reopen_sale
  reopen_params = params.permit(:authorized_by, :notes)
  
  if reopen_params[:authorized_by].blank?
    render json: {
      success: false,
      errors: ["Authorized person name is required"]
    }, status: :unprocessable_entity
    return
  end
  
  # Get current user info
  current_user_name = reopen_params[:authorized_by]
  current_user_id = session[:current_user_id] || 'system'
  
  if @sale.reopen_sale!(
    authorized_by: "#{current_user_name} (ID: #{current_user_id})",
    notes: reopen_params[:notes] || "Sale reopened on #{Date.current.strftime('%d/%m/%Y')}"
  )
    # Log the reopen activity
    Rails.logger.info "SALE REOPEN: Sale #{@sale.invoice_number} reopened by #{current_user_name}"
    
    render json: {
      success: true,
      message: "Sale reopened successfully",
      sale: {
        id: @sale.id,
        invoice_number: @sale.invoice_number,
        is_closed: @sale.is_closed?,
        closure_status: @sale.closure_status,
        financial_summary: @sale.financial_summary
      }
    }, status: :ok
  else
    render json: {
      success: false,
      errors: @sale.errors.full_messages
    }, status: :unprocessable_entity
  end
end

# GET /aruna_solar/api/v1/sales/writeoff_report
def writeoff_report
  start_date = params[:start_date]&.to_date || 30.days.ago.to_date
  end_date = params[:end_date]&.to_date || Date.current
  branch_id = params[:branch_id]

  sales_query = Sale.confirmed.where(writeoff_date: start_date..end_date)
  sales_query = sales_query.where(branch_id: branch_id) if branch_id.present?

  total_writeoffs = sales_query.sum(:writeoff_amount)
  total_sales_value = sales_query.sum(:final_amount)
  total_recovered = sales_query.sum(:paid_amount)
  writeoff_percentage = total_sales_value > 0 ? ((total_writeoffs / total_sales_value) * 100).round(2) : 0
  recovery_rate = total_sales_value > 0 ? (((total_recovered + total_writeoffs) / total_sales_value) * 100).round(2) : 0

  render json: {
    summary: {
      total_writeoffs: total_writeoffs,
      total_sales_value: total_sales_value,
      total_recovered: total_recovered,
      writeoff_percentage: writeoff_percentage,
      recovery_rate: recovery_rate,
      number_of_writeoffs: sales_query.count,
      date_range: "#{start_date.strftime('%d/%m/%Y')} - #{end_date.strftime('%d/%m/%Y')}",
      average_writeoff: sales_query.count > 0 ? (total_writeoffs / sales_query.count).round(2) : 0
    },
    writeoffs: sales_query.includes(:branch).order(:writeoff_date).map do |sale|
      {
        id: sale.id,
        invoice_number: sale.invoice_number,
        customer_name: sale.customer_name,
        branch_name: sale.branch&.name,
        final_amount: sale.final_amount,
        paid_amount: sale.paid_amount,
        writeoff_amount: sale.writeoff_amount,
        writeoff_reason: sale.writeoff_reason,
        writeoff_date: sale.writeoff_date&.strftime('%d/%m/%Y'),
        authorized_by: sale.writeoff_by,
        collection_efficiency: sale.collection_efficiency,
        recovery_rate: sale.recovery_rate,
        closure_status: sale.closure_status,
        closure_notes: sale.closure_notes
      }
    end
  }, status: :ok
end

  # GET /aruna_solar/api/v1/sales/:id/financial_summary
  def financial_summary
    render json: {
      success: true,
      financial_summary: @sale.financial_summary,
      writeoff_summary: @sale.writeoff_summary,
      can_writeoff: @sale.can_writeoff?,
      can_close: @sale.confirmed? && !@sale.is_closed?,
      can_reopen: @sale.is_closed?
    }, status: :ok
  end

  private

  def set_sale
    @sale = Sale.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to sales_path, alert: "Sale not found" }
      format.json do
        render json: {
          success: false,
          errors: ["Sale with ID #{params[:id]} not found"]
        }, status: :not_found
      end
    end
  end

  def sale_params
    params.require(:sale).permit(
      :branch_id, :customer_name, :customer_address, :customer_phone, 
      :customer_gst_number, :sale_date, :discount_amount, :due_date, :notes,
      sale_items_attributes: [
        :id, :product_sku_id, :quantity, :unit_price, 
        :discount_percentage, :_destroy
      ]
    ).tap do |permitted_params|
      permitted_params[:discount_amount] = permitted_params[:discount_amount].presence&.to_f || 0
    end
  end

  def validate_sale_stock(sale_params)
    branch_id = sale_params[:branch_id]
    sale_items = sale_params[:sale_items_attributes] || []
    
    errors = []
    
    sale_items.each do |item_params|
      next if item_params[:_destroy] == '1' || item_params[:product_sku_id].blank?
      
      inventory = Inventory.find_by(
        branch_id: branch_id,
        product_sku_id: item_params[:product_sku_id]
      )
      
      unless inventory
        product = ProductSku.find_by(id: item_params[:product_sku_id])
        errors << "Product '#{product&.sku_name}' is not available in this branch"
        next
      end
      
      requested_quantity = item_params[:quantity].to_i
      available_stock = inventory.quantity
      
      # For edit mode, account for existing quantity if it's an update
      if @sale&.persisted? && item_params[:id].present?
        existing_item = @sale.sale_items.find_by(id: item_params[:id])
        if existing_item
          available_stock += existing_item.quantity
        end
      end
      
      if requested_quantity > available_stock
        errors << "#{inventory.sku_name}: Only #{available_stock} units available, but #{requested_quantity} requested"
      end
    end
    
    {
      valid: errors.empty?,
      errors: errors
    }
  end

  def determine_payment_status(sale)
    return 'completed' if sale.due_amount <= 0
    return 'partial' if sale.paid_amount > 0
    return 'overdue' if sale.overdue?
    'pending'
  end

  def payment_status_breakdown(sales_query)
    breakdown = { completed: 0, partial: 0, pending: 0, overdue: 0 }
    
    sales_query.find_each do |sale|
      status = determine_payment_status(sale)
      breakdown[status.to_sym] += 1
    end
    
    breakdown
  end

  def payment_mode_distribution(sales_query)
    payment_distribution = {}
    
    sales_query.joins(:payments).group('payments.payment_mode').sum('payments.amount').each do |mode, amount|
      payment_distribution[mode.humanize] = amount
    end
    
    payment_distribution.empty? ? {} : payment_distribution
  end

  def calculate_average_collection_efficiency(sales)
    return 0 if sales.empty?
    
    total_efficiency = sales.sum { |sale| sale.collection_efficiency }
    (total_efficiency / sales.count).round(2)
  end
end
