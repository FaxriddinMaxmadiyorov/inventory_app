class Inventory < ApplicationRecord
  include Searchable

  belongs_to :user
  belongs_to :category, optional: true
  has_many :items
  has_many :posts
  has_many :id_elements, -> { order(:position, :id) }
  has_many :inventory_accesses
  has_many :access_users, through: :inventory_accesses, source: :user
  has_many :inventory_tags
  has_many :tags, through: :inventory_tags

  validates :title, presence: true, length: { maximum: 200 }
  validates :image_url, format: { with: %r{\Ahttps?://\S+\z}i }, length: { maximum: 500 }, allow_blank: true
  validate :custom_field_settings_valid

  before_save :build_search_text
  after_save :save_tags

  scope :tagged, ->(name) { joins(:tags).where(tags: { name: name.to_s.downcase }) }
  scope :shared_with, lambda { |user|
    others = where.not(user_id: user.id)
    others.where(is_public: true).or(others.where(id: InventoryAccess.where(user_id: user.id).select(:inventory_id)))
  }

  # Columns that tables may be sorted and filtered by (Ransack).
  def self.ransackable_attributes(_auth_object = nil)
    %w[title items_count created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  # --- access -------------------------------------------------------------

  def manageable_by?(user)
    user.present? && (user.admin? || user.id == user_id)
  end

  def writable_by?(user)
    return false if user.nil?
    return true if manageable_by?(user) || is_public?

    @writers ||= {}
    @writers.fetch(user.id) { @writers[user.id] = inventory_accesses.exists?(user_id: user.id) }
  end

  # --- custom fields ------------------------------------------------------

  # Active custom fields in the order chosen by the owner.
  def custom_fields
    CustomField.all_for(self).select(&:active?).sort_by { |field| [field.position, field.column] }
  end

  def table_fields
    custom_fields.select(&:show_in_table?)
  end

  # Applies the field editor state: an ordered list of
  # { kind, slot, name, description, show, ...tuning } hashes.
  # Slots missing from the list are switched off; item values are left untouched.
  def apply_fields(list)
    attrs = CustomField.all_for(self).to_h { |field| ["#{field.column}_state", false] }
    used = {}

    Array(list).each_with_index do |entry, index|
      entry = entry.to_h.stringify_keys
      kind = entry["kind"].to_s
      slot = entry["slot"].to_i
      next unless CustomField.valid_slot?(kind, slot)

      prefix = "custom_#{kind}#{slot}"
      next if used[prefix]

      used[prefix] = true
      attrs["#{prefix}_state"] = true
      attrs["#{prefix}_name"] = entry["name"].to_s.strip.presence || kind.capitalize
      attrs["#{prefix}_description"] = entry["description"].to_s.strip.presence
      attrs["#{prefix}_show"] = ActiveModel::Type::Boolean.new.cast(entry["show"]) ? true : false
      attrs["#{prefix}_position"] = index
      CustomField::EXTRA_SETTINGS.fetch(kind, []).each do |setting|
        attrs["#{prefix}_#{setting}"] = entry[setting].presence
      end
    end

    assign_attributes(attrs)
  end

  # --- custom IDs ---------------------------------------------------------

  def custom_id_generator
    CustomId.new(id_elements.to_a)
  end

  def replace_id_elements(list)
    rows = Array(list).first(CustomId::MAX_ELEMENTS).each_with_index.filter_map do |entry, index|
      entry = entry.to_h.stringify_keys
      next unless CustomId::KINDS.include?(entry["kind"])

      { inventory_id: id, position: index, kind: entry["kind"], format: entry["format"].to_s.first(100) }
    end

    IdElement.where(inventory_id: id).delete_all
    IdElement.insert_all(rows) if rows.any?
    id_elements.reset
  end

  # --- tags ---------------------------------------------------------------

  def tag_list
    @tag_names || tags.map(&:name)
  end

  def tag_list=(names)
    @tag_names = Array(names).map { |name| name.to_s.strip.downcase.first(50) }.reject(&:empty?).uniq.first(20)
  end

  private

  def custom_field_settings_valid
    custom_fields.each do |field|
      if field.pattern
        begin
          Regexp.new(field.pattern)
        rescue RegexpError
          errors.add(:base, "#{field.name}: #{I18n.t('errors.messages.invalid')} (regex)")
        end
      end
      if field.min && field.max && field.min > field.max
        errors.add(:base, "#{field.name}: min > max")
      end
    end
  end

  def build_search_text
    self.search_text = [title, description, *tag_list].compact.join(" ")
  end

  def save_tags
    return if @tag_names.nil?

    names = @tag_names
    @tag_names = nil
    Tag.insert_all(names.map { |name| { name: name } }, unique_by: :index_tags_on_name) if names.any?
    self.tags = Tag.where(name: names).to_a
  end
end
