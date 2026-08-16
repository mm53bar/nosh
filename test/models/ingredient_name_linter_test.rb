require "test_helper"

class IngredientNameLinterTest < ActiveSupport::TestCase
  # The fixtures are already shopping labels, which is the point — a clean
  # collection reports nothing.
  test "finds nothing in clean names" do
    assert_empty IngredientNameLinter.call
  end

  test "flags a quantity left inside the name" do
    findings = findings_for("400g dried spaghetti")

    assert_includes findings.map(&:rule), :embedded_quantity
  end

  test "flags a parenthetical left inside the name" do
    findings = findings_for("veggie meatballs (e.g. Impossible)")

    assert_includes findings.map(&:rule), :leftover_parenthetical
  end

  test "flags a prep clause left on the end" do
    findings = findings_for("mild salsa, strained of excess liquid")

    assert_includes findings.map(&:rule), :trailing_clause
  end

  test "flags a substitution rather than trimming it" do
    findings = findings_for("white wine or vermouth")

    assert_includes findings.map(&:rule), :substitution
  end

  test "flags a line covering several ingredients" do
    findings = findings_for("thyme, oregano, sage and rosemary")

    assert_includes findings.map(&:rule), :multiple_ingredients
  end

  test "flags a name too long to read in an aisle" do
    findings = findings_for("golden delicious apples peeled and chopped other varieties fine")

    assert_includes findings.map(&:rule), :too_long
  end

  test "flags an emoji that display layers would strip" do
    findings = findings_for("chili crisp ⚠️")

    assert_includes findings.map(&:rule), :symbol
  end

  test "reports the recipe a finding belongs to" do
    finding = findings_for("400g dried spaghetti").first

    assert_equal ingredients(:one).recipe.title, finding.recipe_title
  end

  test "reports every rule a single name trips" do
    rules = findings_for("200g white wine or vermouth (optional)").map(&:rule)

    assert_includes rules, :embedded_quantity
    assert_includes rules, :substitution
    assert_includes rules, :leftover_parenthetical
  end

  private

  def findings_for(name)
    ingredient = ingredients(:one)
    ingredient.update!(name: name)
    IngredientNameLinter.call(Ingredient.where(id: ingredient.id))
  end
end
