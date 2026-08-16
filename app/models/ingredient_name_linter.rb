# Flags ingredient names that aren't shopping labels — names still carrying a
# quantity, a package size, a prep instruction, or several ingredients at once.
#
# This exists because the inflow never stops: RecipeImporter parses whatever
# freeform strings a site puts in schema.org `recipeIngredient`, and nanoclaw's
# recipe-discovery adds recipes over the JSON API every week. IngredientLine
# cleans up what it can prove; this reports what's left for a human.
#
# Deliberately *not* a model validation. A validation would reject legitimate
# imports and start failing nanoclaw's writes — turning a data-quality signal
# into an outage. It reports; it never blocks and never edits.
#
# Run against real data with `bin/rails ingredients:lint` (bin/ci runs on
# fixtures, where there is nothing to find).
class IngredientNameLinter
  MAX_NAME_LENGTH = 40

  Finding = Struct.new(:ingredient, :rule, :detail, keyword_init: true) do
    def recipe_title = ingredient.recipe.title
    def name = ingredient.name
  end

  # Ordered most- to least-mechanical: the first rules describe residue a
  # rewrite can usually fix, the last ones need a decision about what the
  # household actually buys.
  RULES = {
    embedded_quantity: {
      description: "quantity inside the name",
      detect: ->(name) { name.match(/\d+\s*(?:g|kg|ml|l|oz|lb|lbs|tsp|tbsp|cup|cups|ounce|ounces|pound|pounds)\b/i)&.to_s }
    },
    leftover_parenthetical: {
      description: "parenthetical left in the name",
      detect: ->(name) { name[/\([^)]*\)?/] }
    },
    trailing_clause: {
      description: "prep clause left on the end",
      detect: ->(name) { name[/,\s*(#{IngredientLine::PREP_WORDS.join("|")})\b.*/i] }
    },
    substitution: {
      description: "offers alternatives — needs a decision, don't auto-trim",
      detect: ->(name) { name[/\bor\b.*/i] }
    },
    multiple_ingredients: {
      description: "covers more than one ingredient — needs splitting into separate rows",
      detect: ->(name) { name[/\band\b/i] && name.count(",") >= 1 ? name : nil }
    },
    too_long: {
      description: "too long to read on a shopping list",
      detect: ->(name) { "#{name.length} chars" if name.length > MAX_NAME_LENGTH }
    },
    symbol: {
      description: "emoji or symbol — stripped by voice/display layers",
      detect: ->(name) { name[/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}]/] }
    }
  }.freeze

  def self.call(scope = Ingredient.all) = new(scope).call

  def initialize(scope = Ingredient.all)
    @scope = scope
  end

  # One finding per ingredient per rule it trips — a name can be both too long
  # and a substitution, and both facts matter when deciding what to do with it.
  def call
    @scope.includes(:recipe).flat_map do |ingredient|
      RULES.filter_map do |rule, config|
        detail = config[:detect].call(ingredient.name.to_s)
        Finding.new(ingredient: ingredient, rule: rule, detail: detail) if detail.present?
      end
    end
  end
end
