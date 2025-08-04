class BranchListingSerializer < ActiveModel::Serializer
  attributes :id, :name, :address, :city, :state, :pincode,
             :manager_mobile_number, :email, :manager_name, :is_active
end
