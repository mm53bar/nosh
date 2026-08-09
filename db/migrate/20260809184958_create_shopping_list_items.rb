class CreateShoppingListItems < ActiveRecord::Migration[8.1]
  def change
    create_table :shopping_list_items do |t|
      t.string :name, null: false
      t.string :amount
      t.string :unit
      t.string :category
      t.boolean :checked, null: false, default: false

      t.timestamps
    end
  end
end
