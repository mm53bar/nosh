class MealPlanEntry < ApplicationRecord
  belongs_to :recipe

  validates :date, presence: true

  # Ingredient quantities scale to this many servings when the entry is
  # included in a shopping list — an override if given, else the recipe's own.
  def effective_servings
    servings || recipe.servings
  end
end
