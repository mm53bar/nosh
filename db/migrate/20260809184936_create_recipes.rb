class CreateRecipes < ActiveRecord::Migration[8.1]
  def change
    create_table :recipes do |t|
      t.string :title, null: false
      t.string :source_url
      t.text :description
      t.integer :servings
      t.string :cuisine
      t.string :meal_type
      t.integer :prep_time_minutes
      t.integer :total_time_minutes
      t.text :notes
      t.integer :rating
      t.date :last_made_on

      t.timestamps
    end
  end
end
