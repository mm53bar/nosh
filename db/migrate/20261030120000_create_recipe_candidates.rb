class CreateRecipeCandidates < ActiveRecord::Migration[8.1]
  def change
    create_table :recipe_candidates do |t|
      t.string :origin, null: false
      t.string :source_url, null: false
      t.string :title
      t.text :source_text
      t.string :image_url
      t.json :proposal
      t.string :status, null: false, default: "queued"
      t.integer :attempts, null: false, default: 0
      t.string :error
      t.references :recipe, foreign_key: { on_delete: :nullify }
      t.timestamps
    end
    add_index :recipe_candidates, :source_url, unique: true
    add_index :recipe_candidates, :status
  end
end
