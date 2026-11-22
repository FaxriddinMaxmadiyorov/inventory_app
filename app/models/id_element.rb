# One part of an inventory's custom ID format (see CustomId).
class IdElement < ApplicationRecord
  belongs_to :inventory

  validates :kind, inclusion: { in: CustomId::KINDS }
  validates :format, length: { maximum: 100 }
end
