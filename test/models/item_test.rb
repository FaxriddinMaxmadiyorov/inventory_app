require "test_helper"

class ItemTest < ActiveSupport::TestCase
  setup do
    @owner = create_user("Owner")
    @inventory = create_inventory(@owner)
    @inventory.apply_fields([
      { kind: "string", slot: 1, name: "Model", show: true, max_length: 10, pattern: "[A-Z].*" },
      { kind: "number", slot: 1, name: "Price", show: true, min: "0", max: "5000" },
      { kind: "link", slot: 1, name: "Datasheet", show: false },
      { kind: "select", slot: 1, name: "Type", options: "Desktop\nLaptop" },
      { kind: "bool", slot: 1, name: "In use" }
    ])
    @inventory.save!
    @inventory.replace_id_elements([{ kind: "fixed", format: "PC-" }, { kind: "sequence", format: "D3" }])
  end

  test "generates sequential custom IDs" do
    first = @inventory.items.create!(custom_string1: "Dell")
    second = @inventory.items.create!(custom_string1: "Asus")

    assert_equal %w[PC-001 PC-002], [first.custom_id, second.custom_id]
    assert_equal 2, @inventory.reload.items_count
  end

  test "custom ID is unique inside one inventory only" do
    @inventory.items.create!(custom_id: "PC-777")
    duplicate = @inventory.items.new(custom_id: "PC-777")
    assert_not duplicate.valid?

    other = create_inventory(@owner, title: "Other")
    assert other.items.create!(custom_id: "PC-777").persisted?

    # the database refuses duplicates even when validations are skipped
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save(validate: false) }
  end

  test "edited ID must follow the current format" do
    item = @inventory.items.create!
    assert_not item.update(custom_id: "anything")
    assert item.update(custom_id: "PC-999")

    @inventory.replace_id_elements([{ kind: "fixed", format: "X" }, { kind: "sequence", format: "D" }])
    item = Item.find(item.id)
    assert_equal "PC-999", item.custom_id, "existing IDs stay as they are"
    assert_not item.update(custom_string1: "Dell"), "the new format is enforced on edit"
    assert item.update(custom_id: "X5", custom_string1: "Dell")
  end

  test "validates custom field values" do
    item = @inventory.items.new(custom_string1: "lowercase model", custom_number1: "abc", custom_link1: "ftp://x", custom_select1: "Phone")
    assert_not item.valid?
    assert_equal 5, item.errors[:base].size, item.errors.full_messages.inspect

    item = @inventory.items.new(custom_string1: "Dell", custom_number1: "7000")
    assert_not item.valid?

    item = @inventory.items.new(custom_string1: "Dell", custom_number1: "1299,50", custom_link1: "https://example.com/a.pdf", custom_select1: "Laptop", custom_bool1: "1")
    assert item.save, item.errors.full_messages.inspect
    assert_equal BigDecimal("1299.5"), item.custom_number1
  end

  test "full-text search by ID and text values" do
    @inventory.items.create!(custom_string1: "Thinkpad")
    assert_equal 1, Item.search("think").count
    assert_equal 1, Item.search("PC-001").count
    assert_equal 0, Item.search("macbook").count
    assert_equal 0, Item.search("  ").count
    assert_equal 1, Inventory.search("lapt").count
  end

  test "statistics" do
    [["Dell", 100], ["Dell", 300], ["Asus", nil]].each { |model, price| @inventory.items.create!(custom_string1: model, custom_number1: price, custom_bool1: model == "Dell") }
    stats = InventoryStats.new(@inventory.reload)

    price = stats.numbers.first
    assert_equal [2, 200, 100, 300], [price.count, price.average.to_i, price.min.to_i, price.max.to_i]
    assert_equal [["Dell", 2], ["Asus", 1]], stats.popular.first.values
    assert_equal 2, stats.flags.first.checked
  end

  test "optimistic locking" do
    item = @inventory.items.create!
    stale = Item.find(item.id)
    item.update!(custom_string1: "Dell")
    assert_raises(ActiveRecord::StaleObjectError) { stale.update!(custom_string1: "Asus") }
  end
end
