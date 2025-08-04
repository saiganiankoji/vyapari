class Api::V1::BranchController < ApplicationController
  before_action :set_branch, only: [:show, :edit, :update, :toggle_status]

  # UI RENDERING ACTIONS
  def index
    @branches = Branch.filter(filter_params).page(params[:page]).per(10)
    render layout: 'application'
  end

  def show
    render layout: 'application'
  end

  def new
    @branch = Branch.new
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
      branches = Branch.filter(filter_params)
                      .order(created_at: :desc)
                      .page(page)
                      .per(per_page)
      
      render json: {
        message: "Branches retrieved successfully",
        data: {
          branches: ActiveModelSerializers::SerializableResource.new(
            branches, 
            each_serializer: BranchListingSerializer
          ).as_json,
          pagination: {
            current_page: branches.current_page,
            total_pages: branches.total_pages,
            total_count: branches.total_count,
            per_page: branches.limit_value,
            has_next_page: branches.next_page.present?,
            has_prev_page: branches.prev_page.present?
          }
        },
        errors: []
      }, status: :ok
      
    rescue StandardError => e
      Rails.logger.error "Error in branches list: #{e.message}"
      render json: {
        message: "Failed to retrieve branches",
        data: {
          branches: [],
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
    @branch = Branch.new(branch_params)
    
    if @branch.save
      render json: {
        message: "Branch created successfully",
        data: {
          branch: BranchListingSerializer.new(@branch).as_json
        },
        errors: []
      }, status: :created
    else
      render json: {
        message: "Failed to create branch",
        data: {},
        errors: @branch.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def update
    if @branch.update(branch_params)
      render json: {
        message: "Branch updated successfully",
        data: {
          branch: BranchListingSerializer.new(@branch).as_json
        },
        errors: []
      }, status: :ok
    else
      render json: {
        message: "Failed to update branch",
        data: {},
        errors: @branch.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def toggle_status
    @branch.update!(is_active: !@branch.is_active)
    
    render json: {
      message: "Branch status updated successfully to #{@branch.display_status.downcase}",
      data: {
        branch: BranchListingSerializer.new(@branch).as_json
      },
      errors: []
    }, status: :ok
    
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      message: "Failed to update branch status",
      data: {},
      errors: e.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  # Additional API endpoints for better functionality
  def bulk_toggle_status
    branch_ids = params[:branch_ids]
    
    if branch_ids.blank?
      return render json: {
        message: "No branches selected",
        data: {},
        errors: ["Please select at least one branch"]
      }, status: :bad_request
    end

    begin
      branches = Branch.where(id: branch_ids)
      
      if branches.empty?
        return render json: {
          message: "No valid branches found",
          data: {},
          errors: ["No valid branches found with provided IDs"]
        }, status: :not_found
      end

      # Toggle all selected branches
      updated_count = 0
      branches.find_each do |branch|
        if branch.update(is_active: !branch.is_active)
          updated_count += 1
        end
      end

      render json: {
        message: "Successfully updated #{updated_count} branch(es)",
        data: {
          updated_count: updated_count,
          total_selected: branch_ids.length
        },
        errors: []
      }, status: :ok

    rescue StandardError => e
      render json: {
        message: "Failed to update branch statuses",
        data: {},
        errors: [e.message]
      }, status: :internal_server_error
    end
  end

  def search_suggestions
    term = params[:term]&.strip
    limit = [params[:limit].to_i, 20].min
    limit = 10 if limit <= 0

    if term.blank?
      return render json: {
        message: "Search term is required",
        data: { suggestions: [] },
        errors: []
      }
    end

    suggestions = {
      names: Branch.where("name ILIKE ?", "%#{term}%").limit(limit).pluck(:name),
      cities: Branch.where("city ILIKE ?", "%#{term}%").limit(limit).pluck(:city).uniq,
      states: Branch.where("state ILIKE ?", "%#{term}%").limit(limit).pluck(:state).uniq
    }

    render json: {
      message: "Search suggestions retrieved successfully",
      data: { suggestions: suggestions },
      errors: []
    }
  end

  private

  def set_branch
    @branch = Branch.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      message: "Branch not found",
      data: {},
      errors: ["Branch with ID #{params[:id]} not found"]
    }, status: :not_found
  end

  def branch_params
    params.require(:branch).permit(
      :name, :address, :city, :state, :pincode,
      :manager_name, :manager_mobile_number, :email, :is_active
    )
  end

  def filter_params
    # Clean and sanitize filter parameters
    filters = params.permit(:by_name, :by_city, :by_state, :active)
    
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