require "test_helper"

class TechniqueTest < ActiveSupport::TestCase
  test "requires a unique title" do
    technique = Technique.new(title: techniques(:seasoning_cast_iron).title)
    assert_not technique.valid?
    assert_includes technique.errors[:title], "has already been taken"
  end

  test "equipment_names= resolves existing equipment and creates new ones" do
    technique = techniques(:basic_vinaigrette)
    technique.equipment_names = [ "Cast iron pan", "Mason jar" ]
    assert_equal [ "Cast iron pan", "Mason jar" ], technique.equipment_names.sort
    assert Equipment.exists?(name: "Mason jar")
  end

  test "recipes= links existing recipes without creating anything" do
    technique = techniques(:basic_vinaigrette)
    technique.recipes = [ recipes(:two) ]
    assert_equal [ recipes(:two) ], technique.recipes
  end
end
