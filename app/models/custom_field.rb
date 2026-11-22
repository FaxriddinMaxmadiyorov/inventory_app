# A view of one custom field slot of an inventory (for example string #2).
# The slot settings are plain columns of the inventories table
# (custom_string2_state, custom_string2_name, ...), the values are stored in
# the column of the same name in the items table (custom_string2).
class CustomField
  KINDS = %w[string text number link bool select].freeze
  SLOTS = (1..3).freeze
  # Settings every slot has, and the extra "tuning" settings per kind.
  COMMON_SETTINGS = %w[name description show].freeze
  EXTRA_SETTINGS = { "string" => %w[max_length pattern], "number" => %w[min max], "select" => %w[options] }.freeze

  attr_reader :inventory, :kind, :slot

  def self.all_for(inventory)
    KINDS.flat_map { |kind| SLOTS.map { |slot| new(inventory, kind, slot) } }
  end

  def self.valid_slot?(kind, slot)
    KINDS.include?(kind) && SLOTS.cover?(slot)
  end

  def self.item_columns
    @item_columns ||= KINDS.flat_map { |kind| SLOTS.map { |slot| "custom_#{kind}#{slot}" } }.freeze
  end

  def initialize(inventory, kind, slot)
    @inventory = inventory
    @kind = kind
    @slot = slot
  end

  # Name of the items column that keeps the value, also the prefix of the settings columns.
  def column
    "custom_#{kind}#{slot}"
  end

  def setting(name)
    inventory["#{column}_#{name}"]
  end

  def active?
    setting(:state)
  end

  def name
    setting(:name).presence || column
  end

  def description
    setting(:description)
  end

  def show_in_table?
    setting(:show)
  end

  def position
    setting(:position)
  end

  def max_length
    setting(:max_length) if kind == "string"
  end

  def pattern
    setting(:pattern).presence if kind == "string"
  end

  def min
    setting(:min) if kind == "number"
  end

  def max
    setting(:max) if kind == "number"
  end

  def options
    kind == "select" ? setting(:options).to_s.split(/\r?\n/).map(&:strip).reject(&:empty?).uniq : []
  end

  def textual?
    %w[string text select link].include?(kind)
  end
end
