class MealPlanEntry < ApplicationRecord
  # A night can be planned without a recipe ("Burrito night"): it has a title
  # instead, shows on the plan and the kitchen screen, and adds nothing to the
  # shopping list.
  belongs_to :recipe, optional: true

  validates :date, presence: true
  validates :recipe, presence: { message: "must exist" }, if: :recipe_id?
  validates :title, presence: true, unless: :recipe
  normalizes :title, with: ->(title) { title.squish.presence }

  def name = recipe&.title || title

  # Ingredient quantities scale to this many servings when the entry is
  # included in a shopping list — an override if given, else the recipe's own.
  def effective_servings
    servings || recipe&.servings
  end
end
