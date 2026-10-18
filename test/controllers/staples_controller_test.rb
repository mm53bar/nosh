require "test_helper"

class StaplesControllerTest < ActionDispatch::IntegrationTest
  test "need answers with something to say" do
    post need_staples_path, params: { item: "milk" }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Added milk.", body["speech"]
    assert_equal "staple", body["matches"].first["kind"]
  end

  # A refusal is an answer, not an error — the voice layer just speaks it.
  test "an unknown item is still a 200" do
    post need_staples_path, params: { item: "advil" }, as: :json

    assert_response :success
    assert_equal "unknown", JSON.parse(response.body)["matches"].first["kind"]
  end

  test "have crosses off" do
    post have_staples_path, params: { item: "butter" }, as: :json

    assert_equal "Crossed off butter.", JSON.parse(response.body)["speech"]
  end

  # The kitchen screen has no session, so the board's writes must work as bare JSON.
  test "a tab can be flipped without a CSRF token" do
    ActionController::Base.allow_forgery_protection = true

    patch staple_path(staples(:milk), format: :json), params: { staple: { needed: true } }.to_json,
          headers: { "Content-Type" => "application/json" }

    assert_response :success
    assert staples(:milk).reload.needed?
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "creating a tab by aisle name" do
    post staples_path, params: { staple: { name: "tofu", aisle_name: "Dairy", aliases: [ "extra firm tofu" ] } }, as: :json

    assert_response :created
    assert_equal aisles(:dairy), Staple.find_by!(name: "tofu").aisle
  end

  test "a group word is refused as a tab" do
    post staples_path, params: { staple: { name: "oil", aisle_name: "Pantry" } }, as: :json

    assert_response :unprocessable_entity
  end

  # The voice layer can feed this vocabulary to speech-to-text as hints.
  test "the board's vocabulary is readable as json" do
    get staples_path, as: :json

    dairy = JSON.parse(response.body).find { |aisle| aisle["aisle"] == "Dairy" }
    assert_includes dairy["staples"].map { |staple| staple["name"] }, "parmesan"
  end
end
