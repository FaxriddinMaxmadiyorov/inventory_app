class LikesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_item

  def create
    @item.likes.create(user: current_user)
    redirect_to inventory_item_path(@item.inventory_id, @item)
  rescue ActiveRecord::RecordNotUnique
    redirect_to inventory_item_path(@item.inventory_id, @item)
  end

  def destroy
    @item.likes.find_by(user_id: current_user.id)&.destroy
    redirect_to inventory_item_path(@item.inventory_id, @item)
  end

  private

  def set_item
    @item = Item.where(inventory_id: params[:inventory_id]).find(params[:item_id])
  end
end
