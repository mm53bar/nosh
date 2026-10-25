class AddSourceToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :source_data, :json
    add_column :recipes, :source_fetched_at, :datetime
  end
end
