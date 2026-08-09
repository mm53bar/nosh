require "test_helper"

class TechniquesControllerTest < ActionDispatch::IntegrationTest
  test "index lists techniques" do
    get techniques_path
    assert_response :success
    assert_select "h2", text: techniques(:seasoning_cast_iron).title
  end

  test "create with equipment_names_text resolves/creates equipment" do
    post techniques_path, params: { technique: { title: "New Technique", body: "Do the thing.", equipment_names_text: "Cast iron pan, Tongs" } }

    technique = Technique.find_by!(title: "New Technique")
    assert_redirected_to technique
    assert_equal [ "Cast iron pan", "Tongs" ], technique.equipment.map(&:name).sort
  end

  test "show displays recipes that reference this technique" do
    recipes(:one).techniques << techniques(:seasoning_cast_iron)

    get technique_path(techniques(:seasoning_cast_iron))
    assert_response :success
    assert_select "a", text: recipes(:one).title
  end
end
