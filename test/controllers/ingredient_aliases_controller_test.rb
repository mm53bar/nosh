require "test_helper"

class IngredientAliasesControllerTest < ActionDispatch::IntegrationTest
  test "create renames existing ingredients and reports how many" do
    post ingredient_aliases_path(format: :json), params: { ingredient_alias: { variant: "tofu", canonical: "firm tofu" } }, as: :json

    assert_response :created
    assert_equal 1, response.parsed_body["renamed"]
    assert_equal "firm tofu", ingredients(:one).reload.name
  end

  test "posting a variant again re-points it instead of failing" do
    IngredientAlias.create!(variant: "tofu", canonical: "firm tofu")

    post ingredient_aliases_path(format: :json), params: { ingredient_alias: { variant: "Tofu", canonical: "extra-firm tofu" } }, as: :json

    assert_response :ok
    assert_equal "extra-firm tofu", IngredientAlias.canonical_for("tofu")
    assert_equal 1, IngredientAlias.count
  end

  test "create reports a refused alias" do
    post ingredient_aliases_path(format: :json), params: { ingredient_alias: { variant: "tofu", canonical: "" } }, as: :json

    assert_response :unprocessable_entity
  end

  test "index lists and destroy removes" do
    ingredient_alias = IngredientAlias.create!(variant: "scallions", canonical: "green onions")

    get ingredient_aliases_path(format: :json)
    assert_equal [ { "id" => ingredient_alias.id, "variant" => "scallions", "canonical" => "green onions" } ], response.parsed_body

    delete ingredient_alias_path(ingredient_alias, format: :json)
    assert_response :no_content
    assert_nil IngredientAlias.canonical_for("scallions")
  end
end
