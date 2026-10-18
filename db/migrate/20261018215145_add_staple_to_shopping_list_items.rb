class AddStapleToShoppingListItems < ActiveRecord::Migration[8.1]
  def change
    add_reference :shopping_list_items, :staple, foreign_key: { on_delete: :nullify }
  end
end
