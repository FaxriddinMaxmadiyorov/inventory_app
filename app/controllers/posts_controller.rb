class PostsController < ApplicationController
  before_action :authenticate_user!, only: :create
  before_action :set_inventory

  # Posts newer than ?after=ID, as an HTML fragment. The discussion tab polls it.
  def index
    posts = @inventory.posts.includes(:user).where("posts.id > ?", params[:after].to_i).order(:id).limit(100)
    render partial: "posts/post", collection: posts
  end

  def create
    post = @inventory.posts.new(body: params[:body], user: current_user)
    if post.save
      head :created
    else
      render json: { error: post.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  private

  def set_inventory
    @inventory = Inventory.find(params[:inventory_id])
  end
end
