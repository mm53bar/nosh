require "test_helper"

class Kitchen::ShoppingListsControllerTest < ActionDispatch::IntegrationTest
  test "every tab is on the board, tappable, with what's needed checked" do
    staple = staples(:milk)
    staple.update!(needed: true)
    get kitchen_shopping_list_path

    assert_response :success
    assert_nil response.headers["X-Frame-Options"]
    assert_select "input[data-url=?][checked]", staple_path(staple, format: :json)
    assert_select "input[data-param='staple[needed]']", Staple.count
  end

  test "no typing on the kiosk" do
    get kitchen_shopping_list_path

    assert_select "input[type=text], input[type=search]", 0
  end

  test "embedded, the corner is left clear" do
    get kitchen_shopping_list_path(embed: 1)

    assert_select "header.ps-\\[74px\\]"
  end

  test "write-ins can be ticked off" do
    write_in = WriteIn.create!(name: "birthday candles")
    get kitchen_shopping_list_path

    assert_select "input[data-url=?]", write_in_path(write_in, format: :json)
  end

  test "a tap that didn't save can say so" do
    get kitchen_shopping_list_path

    assert_select "[data-controller~=toast]"
  end
end
