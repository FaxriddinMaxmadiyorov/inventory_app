class HomeController < ApplicationController
  def index
    @latest = Inventory.includes(:user, :category).order(created_at: :desc).limit(10)
    @popular = Inventory.includes(:user, :category).order(items_count: :desc, id: :asc).limit(5)
    @tags = Tag.cloud
  end
end
