class ItemsController < ApplicationController
  before_action :set_inventory
  before_action :authenticate_user!, except: :show
  before_action :require_writer!, except: :show
  before_action :set_item, only: %i[show update]

  def new
    @item = @inventory.items.new
  end

  def create
    @item = @inventory.items.new(item_params)
    @item.user = current_user

    if save_item
      redirect_to inventory_path(@inventory), notice: t("flash.item_created", id: @item.custom_id)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @can_write = @inventory.writable_by?(current_user)
    @liked = @item.liked_by?(current_user)
  end

  def update
    @item.assign_attributes(item_params)

    if save_item
      redirect_to inventory_item_path(@inventory, @item), notice: t("flash.saved")
    else
      @can_write = true
      @liked = @item.liked_by?(current_user)
      render :show, status: :unprocessable_entity
    end
  rescue ActiveRecord::StaleObjectError
    # Somebody saved this item after the form was opened. Nothing is overwritten:
    # the user gets the form back with a link to reload the current values.
    @stale = true
    @can_write = true
    @liked = @item.liked_by?(current_user)
    render :show, status: :conflict
  end

  def bulk_destroy
    scope, requested = versioned(@inventory.items, params[:ids])
    deleted = scope.delete_all
    Inventory.update_counters(@inventory.id, items_count: -deleted) if deleted.positive?

    redirect_to inventory_path(@inventory), notice: bulk_delete_message(deleted, requested)
  end

  private

  def set_inventory
    @inventory = Inventory.find(params[:inventory_id])
  end

  def set_item
    @item = @inventory.items.find(params[:id])
  end

  def require_writer!
    forbidden! unless @inventory.writable_by?(current_user)
  end

  def item_params
    params.fetch(:item, {}).permit(:custom_id, :lock_version, *@inventory.custom_fields.map(&:column))
  end

  # The database has the final word on ID uniqueness (two users may save at once).
  def save_item
    @item.save
  rescue ActiveRecord::RecordNotUnique
    @item.errors.add(:custom_id, :taken)
    false
  end
end
