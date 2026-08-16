class AddNoteToIngredients < ActiveRecord::Migration[8.1]
  def change
    add_column :ingredients, :note, :string
  end
end
