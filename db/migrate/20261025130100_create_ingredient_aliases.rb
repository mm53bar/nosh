class CreateIngredientAliases < ActiveRecord::Migration[8.1]
  def change
    create_table :ingredient_aliases do |t|
      t.string :variant, null: false
      t.string :canonical, null: false
      t.timestamps
    end
    add_index :ingredient_aliases, :variant, unique: true
  end
end
