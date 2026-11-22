class Tag < ApplicationRecord
  has_many :inventory_tags
  has_many :inventories, through: :inventory_tags

  validates :name, presence: true, uniqueness: true, length: { maximum: 50 }

  scope :starting_with, ->(prefix) { where("name LIKE ?", "#{sanitize_sql_like(prefix.to_s.downcase)}%") }

  # [[tag, inventories_count], ...] for the tag cloud, one query.
  def self.cloud(limit = 40)
    joins(:inventory_tags).group(:id).order(Arel.sql("COUNT(*) DESC")).limit(limit)
                          .select("tags.*, COUNT(*) AS uses_count").sort_by(&:name)
  end
end
