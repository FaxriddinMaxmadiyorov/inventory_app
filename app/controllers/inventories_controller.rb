require "csv"

class InventoriesController < ApplicationController
  TABS = %w[items chat settings custom_id fields access stats export].freeze
  MANAGER_TABS = %w[settings custom_id fields access export].freeze

  before_action :authenticate_user!, except: :show
  before_action :set_inventory, only: %i[show autosave custom_id_preview export]
  before_action :require_manager!, only: %i[autosave custom_id_preview export]

  def show
    @can_manage = @inventory.manageable_by?(current_user)
    @can_write = @inventory.writable_by?(current_user)
    @tab = TABS.include?(params[:tab]) ? params[:tab] : "items"
    @tab = "items" if MANAGER_TABS.include?(@tab) && !@can_manage

    case @tab
    when "items"
      @fields = @inventory.table_fields
      @items_search = @inventory.items.ransack(ransack_params)
      @items_search.sorts = "created_at desc" if @items_search.sorts.empty?
      @items = @items_search.result.page(params[:page]).per(25)
    when "chat"
      @posts = @inventory.posts.includes(:user).order(id: :desc).limit(200).reverse
    when "access"
      @access_search = @inventory.access_users.ransack(ransack_params)
      @access_search.sorts = "name asc" if @access_search.sorts.empty?
      @access_users = @access_search.result
    when "stats"
      @stats = InventoryStats.new(@inventory)
    end
  end

  # A new inventory is created right away and opened on the settings tab,
  # where everything is edited with auto-save.
  def create
    inventory = current_user.inventories.create!(title: t("inventories.new_title"))
    redirect_to inventory_path(inventory, tab: "settings")
  end

  def bulk_destroy
    scope = current_user.admin? ? Inventory.all : current_user.inventories
    scope, requested = versioned(scope, params[:ids])
    deleted = scope.delete_all # items, posts, tags links etc. go with ON DELETE CASCADE

    redirect_back fallback_location: user_path(current_user), notice: bulk_delete_message(deleted, requested)
  end

  # Auto-save endpoint. The client sends the version it has; the save either
  # succeeds and returns the next version, or fails with 409 if somebody else
  # has changed the inventory in the meantime.
  def autosave
    Inventory.transaction do
      @inventory.lock_version = params[:lock_version].to_i
      @inventory.assign_attributes(inventory_params) if params[:inventory].present?
      @inventory.tag_list = params.dig(:inventory, :tags) if params[:inventory]&.key?(:tags)
      @inventory.apply_fields(hash_list(:fields)) if params.key?(:fields)
      @inventory.replace_id_elements(hash_list(:id_elements)) if params.key?(:id_elements)
      @inventory.updated_at = Time.current
      @inventory.save!
    end

    render json: { lock_version: @inventory.lock_version, title: @inventory.title,
                   example: @inventory.custom_id_generator.example }
  rescue ActiveRecord::StaleObjectError
    render json: { error: t("flash.stale") }, status: :conflict
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def custom_id_preview
    render json: { example: CustomId.new(hash_list(:id_elements).first(CustomId::MAX_ELEMENTS)).example }
  end

  def export
    fields = @inventory.custom_fields
    header = ["ID", *fields.map(&:name), t("items.created_by"), t("items.created_at"), t("items.likes")]
    rows = @inventory.items.includes(:user).order(:id)
    to_row = lambda do |item|
      [item.custom_id, *fields.map { |f| export_value(item[f.column]) }, item.user&.name, item.created_at.iso8601, item.likes_count]
    end
    filename = "#{@inventory.title.parameterize.presence || 'inventory'}-#{Date.current}"

    respond_to do |format|
      format.csv do
        data = CSV.generate { |csv| csv << header; rows.find_each { |item| csv << to_row.call(item) } }
        send_data data, filename: "#{filename}.csv", type: "text/csv; charset=utf-8"
      end
      format.xlsx do
        package = Axlsx::Package.new
        package.workbook.add_worksheet(name: "Items") do |sheet|
          sheet.add_row header
          rows.find_each { |item| sheet.add_row to_row.call(item) }
        end
        send_data package.to_stream.read, filename: "#{filename}.xlsx",
                                          type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      end
    end
  end

  private

  def set_inventory
    @inventory = Inventory.find(params[:id])
  end

  def require_manager!
    forbidden! unless @inventory.manageable_by?(current_user)
  end

  def inventory_params
    params.require(:inventory).permit(:title, :description, :category_id, :image_url, :is_public)
  end

  def hash_list(key)
    Array(params[key]).filter_map { |entry| entry.permit!.to_h if entry.respond_to?(:permit!) }
  end

  def export_value(value)
    value.is_a?(BigDecimal) ? value.to_s("F").sub(/\.0+\z/, "") : value
  end
end
