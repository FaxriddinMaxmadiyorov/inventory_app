module Admin
  class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!

    OPERATIONS = {
      "block" => { blocked: true }, "unblock" => { blocked: false },
      "promote" => { admin: true }, "demote" => { admin: false }
    }.freeze

    def index
      @search = User.ransack(ransack_params)
      @search.sorts = "name asc" if @search.sorts.empty?
      @users = @search.result.page(params[:page]).per(25)
    end

    # One action for the whole toolbar. Admins may block, demote or delete
    # themselves too; they simply lose access right after that.
    def bulk
      users = User.where(id: Array(params[:ids]))

      if OPERATIONS.key?(params[:op])
        users.update_all(OPERATIONS[params[:op]].merge(updated_at: Time.current))
      elsif params[:op] == "delete"
        Item.where(id: Like.where(user_id: users.select(:id)).select(:item_id)).update_all("likes_count = likes_count - 1")
        users.delete_all # inventories, posts, likes and access records go with ON DELETE CASCADE
      end

      # back to the same page of the list, with its filter and sorting
      redirect_back fallback_location: admin_users_path, notice: t("flash.saved")
    end
  end
end
