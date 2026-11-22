class InventoryTag < ApplicationRecord
  belongs_to :inventory
  belongs_to :tag
end
