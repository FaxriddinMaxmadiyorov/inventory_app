class UsersController < ApplicationController
  before_action :authenticate_user!, only: :autocomplete

  def show
    @user = User.find(params[:id])
    @own_page = user_signed_in? && (current_user.id == @user.id || current_user.admin?)

    @owned_search = @user.inventories.includes(:category).ransack(ransack_params)
    @owned_search.sorts = "created_at desc" if @owned_search.sorts.empty?
    @owned = @owned_search.result.page(params[:page]).per(20)

    return unless @own_page

    # The second table on the page keeps its filter and sorting under its own key.
    @writable_search = Inventory.shared_with(@user).includes(:user, :category).ransack(ransack_params(:wq), search_key: :wq)
    @writable_search.sorts = "title asc" if @writable_search.sorts.empty?
    @writable = @writable_search.result.page(params[:wpage]).per(20)
  end

  # Users whose name or e-mail starts with the typed text (for the access list).
  def autocomplete
    users = params[:q].present? ? User.starting_with(params[:q]).order(:name).limit(10) : []
    render json: users.map { |user| { id: user.id, name: user.name, email: user.email } }
  end
end
