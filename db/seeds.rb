# Categories are managed directly in the database; there is no UI for them.
%w[Equipment Furniture Book Document Other].each do |name|
  Category.find_or_create_by!(name: name)
end

if Rails.env.development? && User.none?
  admin = User.new(name: "Admin", email: "admin@example.com", password: "password", admin: true)
  admin.skip_confirmation!
  admin.save!
  puts "Created admin@example.com / password"
end

# A small demo inventory so the first screen is not empty.
if Rails.env.development? && Inventory.none?
  admin = User.find_by!(email: "admin@example.com")
  inventory = admin.inventories.new(title: "Company Owned Computers", description: "All **computers** used in the office.",
                                    category: Category.find_by(name: "Equipment"), is_public: true)
  inventory.tag_list = %w[office hardware]
  inventory.apply_fields([
    { kind: "string", slot: 1, name: "Model", description: "Manufacturer and model", show: true },
    { kind: "number", slot: 1, name: "Price", description: "In USD", show: true, min: 0 },
    { kind: "select", slot: 1, name: "Type", show: true, options: "Desktop\nLaptop" },
    { kind: "bool", slot: 1, name: "In use", show: true },
    { kind: "link", slot: 1, name: "Photo or invoice", show: false },
    { kind: "text", slot: 1, name: "Notes", show: false }
  ])
  inventory.save!
  inventory.replace_id_elements([
    { kind: "fixed", format: "COMP-" }, { kind: "datetime", format: "yyyy-" },
    { kind: "rand32", format: "X8-" }, { kind: "sequence", format: "D3" }
  ])
  [["Lenovo ThinkPad T14", 1450, "Laptop", true], ["Dell OptiPlex 7010", 890, "Desktop", true], ["Apple MacBook Air", 1299, "Laptop", false]].each do |model, price, type, used|
    inventory.items.create!(user: admin, custom_string1: model, custom_number1: price, custom_select1: type, custom_bool1: used)
  end
end
