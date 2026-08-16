# Aggregates ingredients across every meal-plan entry in a date range, scaling
# amounts by servings-override/recipe-servings, then replaces the entire
# shopping list with the result. Ported from the old app's generateShoppingList
# (db.js) — the one piece of business logic worth carrying over deliberately
# rather than re-deriving from scratch.
class ShoppingListBuilder
  def self.generate(start_date:, end_date:)
    new(start_date: start_date, end_date: end_date).generate
  end

  def initialize(start_date:, end_date:)
    @start_date = start_date
    @end_date = end_date
  end

  def generate
    aggregated = aggregate_ingredients

    ShoppingListItem.transaction do
      ShoppingListItem.delete_all
      aggregated.each_value do |item|
        ShoppingListItem.create!(
          name: item[:name],
          amount: combined_amount(item[:amounts]),
          unit: item[:unit],
          source: item[:sources].uniq.join(", ").presence
        )
      end
    end

    ShoppingListItem.all
  end

  private

  def aggregate_ingredients
    entries = MealPlanEntry.includes(recipe: :ingredients).where(date: @start_date..@end_date)

    aggregated = {}
    entries.each do |entry|
      scale = entry.servings.present? && entry.recipe.servings.present? ? entry.servings.to_f / entry.recipe.servings : 1

      entry.recipe.ingredients.each do |ingredient|
        key = "#{ingredient.name.downcase}|#{ingredient.unit.to_s.downcase}"
        item = aggregated[key] ||= { name: ingredient.name, unit: ingredient.unit, amounts: [], sources: [] }
        # Kept so a shopping list can say *why* an item is on it — "tahini,
        # 200 g · Tofu Noodles" answers a question a bare name cannot.
        item[:sources] << entry.recipe.title
        next if ingredient.amount.blank?

        numeric = Float(ingredient.amount, exception: false)
        item[:amounts] << (numeric ? numeric * scale : ingredient.amount)
      end
    end
    aggregated
  end

  def combined_amount(amounts)
    return nil if amounts.empty?

    if amounts.all? { |amount| amount.is_a?(Numeric) }
      amounts.sum.round(1).to_s
    else
      amounts.join(", ")
    end
  end
end
