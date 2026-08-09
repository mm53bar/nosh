class TechniqueEquipment < ApplicationRecord
  belongs_to :technique
  belongs_to :equipment

  validates :equipment_id, uniqueness: { scope: :technique_id }
end
