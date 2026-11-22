class Item < ApplicationRecord
  include Searchable

  URL_FORMAT = %r{\Ahttps?://\S+\z}i
  NUMBER_FORMAT = /\A\s*[+-]?\d+([.,]\d+)?\s*\z/

  belongs_to :inventory, counter_cache: true
  belongs_to :user, optional: true
  has_many :likes

  before_validation :normalize_values
  before_validation :assign_sequence_and_custom_id, on: :create

  validates :custom_id, presence: true, length: { maximum: 200 }, uniqueness: { scope: :inventory_id }
  validate :custom_id_follows_format
  validate :custom_values_valid

  before_save :build_search_text

  # Columns that the items table may be sorted and filtered by (Ransack).
  def self.ransackable_attributes(_auth_object = nil)
    %w[custom_id created_at likes_count search_text] + CustomField.item_columns
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def liked_by?(user)
    user.present? && likes.exists?(user_id: user.id)
  end

  private

  def normalize_values
    self.custom_id = custom_id.to_s.strip.presence
    inventory.custom_fields.each do |field|
      if field.textual?
        self[field.column] = self[field.column].to_s.strip.presence
      elsif field.kind == "number"
        raw = read_attribute_before_type_cast(field.column)
        self[field.column] = raw.tr(",", ".").strip if raw.is_a?(String) && raw.match?(NUMBER_FORMAT)
      end
    end
  end

  # The sequence is the largest one used in the inventory plus one. Two users adding
  # items at the same moment can produce the same ID; the unique index rejects the
  # second insert and that user corrects the ID by hand.
  def assign_sequence_and_custom_id
    self.sequence = inventory.items.maximum(:sequence).to_i + 1
    self.custom_id ||= inventory.custom_id_generator.generate(sequence: sequence)
  end

  def custom_id_follows_format
    return if custom_id.blank?

    generator = inventory.custom_id_generator
    errors.add(:custom_id, :invalid_format, example: generator.example) unless generator.valid?(custom_id)
  end

  def custom_values_valid
    inventory.custom_fields.each do |field|
      value = self[field.column]

      case field.kind
      when "string"
        limit = [field.max_length, 255].compact.min
        field_error(field, :too_long, count: limit) if value.to_s.length > limit
        field_error(field, :invalid) if value && field.pattern && !matches_pattern?(field.pattern, value)
      when "number"
        raw = read_attribute_before_type_cast(field.column)
        if raw.is_a?(String) && raw.present? && !raw.match?(NUMBER_FORMAT)
          field_error(field, :not_a_number)
        elsif value
          field_error(field, :greater_than_or_equal_to, count: format_decimal(field.min)) if field.min && value < field.min
          field_error(field, :less_than_or_equal_to, count: format_decimal(field.max)) if field.max && value > field.max
        end
      when "link"
        field_error(field, :invalid) if value && (!value.match?(URL_FORMAT) || value.length > 255)
      when "select"
        field_error(field, :inclusion) if value && !field.options.include?(value)
      end
    end
  end

  def matches_pattern?(pattern, value)
    Regexp.new("\\A(?:#{pattern})\\z").match?(value)
  rescue RegexpError
    true
  end

  def format_decimal(number)
    number.to_s("F").sub(/\.0+\z/, "")
  end

  def field_error(field, type, **options)
    errors.add(:base, "#{field.name}: #{I18n.t("errors.messages.#{type}", **options)}")
  end

  def build_search_text
    values = inventory.custom_fields.select(&:textual?).map { |field| self[field.column] }
    self.search_text = [custom_id, *values].compact.join(" ")
  end
end
