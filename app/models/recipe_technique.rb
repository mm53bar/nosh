class RecipeTechnique < ApplicationRecord
  belongs_to :recipe
  belongs_to :technique

  validates :technique_id, uniqueness: { scope: :recipe_id }
end
