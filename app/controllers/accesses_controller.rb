class AccessesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_inventory

  def create
    user = User.find_by(id: params[:user_id])
    @inventory.inventory_accesses.create(user: user) if user && user.id != @inventory.user_id
    redirect_to inventory_path(@inventory, tab: "access")
  rescue ActiveRecord::RecordNotUnique
    redirect_to inventory_path(@inventory, tab: "access")
  end

  def bulk_destroy
    @inventory.inventory_accesses.where(user_id: Array(params[:ids])).delete_all
    redirect_to inventory_path(@inventory, tab: "access")
  end

  private

  def set_inventory
    @inventory = Inventory.find(params[:inventory_id])
    forbidden! unless @inventory.manageable_by?(current_user)
  end
end
