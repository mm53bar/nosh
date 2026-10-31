class RemoveCategoryFromShoppingListItems < ActiveRecord::Migration[8.1]
  def change
    remove_column :shopping_list_items, :category, :string
  end
end
