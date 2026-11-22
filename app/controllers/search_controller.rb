class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @tag = params[:tag].to_s.strip

    if @tag.present?
      @inventories = Inventory.tagged(@tag)
      @items = Item.none
    else
      @inventories = Inventory.search(@query)
      @items = Item.search(@query)
    end

    @inventories = @inventories.includes(:user, :category).order(created_at: :desc).page(params[:page]).per(20)
    @items = @items.includes(:inventory).order(created_at: :desc).page(params[:items_page]).per(20)
  end
end
