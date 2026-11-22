class TagsController < ApplicationController
  # Tag autocomplete: existing tags that start with the typed text.
  def index
    names = params[:q].present? ? Tag.starting_with(params[:q]).order(:name).limit(10).pluck(:name) : []
    render json: names
  end
end
