# Aggregates ingredients across every meal-plan entry in a date range, scaling
# amounts by servings-override/recipe-servings, then replaces the entire
# shopping list with the result. An ingredient that is a staple is attached to
# its tab as a marker and never flips it — only a person knows the cupboard is
# empty (docs/adr/20261018-shopping-list-is-a-staples-board.md). Ported from the old app's generateShoppingList
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
    matcher = StapleMatcher.new

    ShoppingListItem.transaction do
      ShoppingListItem.delete_all
      aggregated.each_value do |item|
        match = matcher.match(item[:name].to_s.split(",").first)
        # A recipe that just says "oil" or "pepper" names a group of tabs, not
        # one: it's a staple whichever it means, so it isn't a "this week" line,
        # and there's no single tab to mark.
        next if match.group?

        ShoppingListItem.create!(
          name: item[:name],
          amount: combined_amount(item[:amounts]),
          unit: item[:unit],
          source: item[:sources].uniq.join(", ").presence,
          staple: (match.staple if match.staple?)
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
      amounts.sum.round(1).to_s.delete_suffix(".0")
    else
      amounts.join(", ")
    end
  end
end
