class RecipeEquipment < ApplicationRecord
  belongs_to :recipe
  belongs_to :equipment

  validates :equipment_id, uniqueness: { scope: :recipe_id }
end
