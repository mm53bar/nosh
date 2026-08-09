class CreateTechniques < ActiveRecord::Migration[8.1]
  def change
    create_table :techniques do |t|
      t.string :title, null: false
      t.text :body

      t.timestamps
    end

    add_index :techniques, :title, unique: true
  end
end
