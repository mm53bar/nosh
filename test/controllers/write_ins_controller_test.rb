require "test_helper"

class WriteInsControllerTest < ActionDispatch::IntegrationTest
  test "typing a tab's name flips the tab instead of writing it in" do
    assert_no_difference -> { WriteIn.count } do
      post write_ins_path, params: { write_in: { name: "Milk" } }, as: :json
    end

    assert_equal "staple", JSON.parse(response.body)["kind"]
    assert staples(:milk).reload.needed?
  end

  test "typing a group word asks which one" do
    assert_no_difference -> { WriteIn.count } do
      post write_ins_path, params: { write_in: { name: "cheese" } }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal %w[parmesan feta], JSON.parse(response.body)["choices"]
  end

  test "anything else is written in" do
    assert_difference -> { WriteIn.count } do
      post write_ins_path, params: { write_in: { name: "Tinfoil" } }, as: :json
    end

    assert_equal "write_in", JSON.parse(response.body)["kind"]
  end

  test "writing in something already written in doesn't duplicate it" do
    assert_no_difference -> { WriteIn.count } do
      post write_ins_path, params: { write_in: { name: "birthday candle" } }, as: :json
    end
  end

  test "the third time a name is written in, it can be promoted" do
    assert write_ins(:advil_open).promotable?
    assert_not write_ins(:candles).promotable?
  end

  test "promoting makes a tab that is already flipped" do
    post promote_write_in_path(write_ins(:advil_open), format: :json), params: { aisle_id: aisles(:pantry).id }, as: :json

    assert_response :created
    assert Staple.find_by!(name: "advil").needed?
    assert_not WriteIn.exists?(write_ins(:advil_open).id)
  end

  test "checking one off hides it" do
    patch write_in_path(write_ins(:candles), format: :json), params: { write_in: { bought: true } }, as: :json

    assert_not_includes WriteIn.open, write_ins(:candles)
  end
end
