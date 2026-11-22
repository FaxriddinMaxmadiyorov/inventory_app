# Ransack sorts and filters the tables (personal page, items, access list, admin).
# Which columns may be used is declared per model in ransackable_attributes.
Ransack.configure do |config|
  # Sort direction marks in table headers, as Bootstrap icons.
  config.custom_arrows = {
    up_arrow: '<i class="bi bi-caret-up-fill small"></i>',
    down_arrow: '<i class="bi bi-caret-down-fill small"></i>'
  }
end
