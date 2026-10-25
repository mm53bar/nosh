class AddOriginalTextToIngredients < ActiveRecord::Migration[8.1]
  def change
    add_column :ingredients, :original_text, :string
  end
end
