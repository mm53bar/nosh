class StoreAmountsAsNumbers < ActiveRecord::Migration[8.1]
  TABLES = %i[ingredients shopping_list_items].freeze

  def up
    TABLES.each do |table|
      rename_column table, :amount, :amount_text
      add_column table, :amount, :decimal, precision: 12, scale: 4
      add_column table, :amount_max, :decimal, precision: 12, scale: 4
      backfill(table)
      remove_column table, :amount_text
    end
  end

  def down
    TABLES.each do |table|
      add_column table, :amount_text, :string
      rows(table).find_each do |row|
        row.update_columns(amount_text: IngredientAmount.format(row.amount, row.amount_max)&.tr("–", "-"))
      end
      remove_column table, :amount_max
      remove_column table, :amount
      rename_column table, :amount_text, :amount
    end
  end

  private

  def rows(table)
    Class.new(ActiveRecord::Base) { self.table_name = table }.tap(&:reset_column_information)
  end

  def backfill(table)
    rows(table).where.not(amount_text: [ nil, "" ]).find_each do |row|
      parsed = IngredientAmount.parse(row.amount_text)
      if parsed
        row.update_columns(amount: parsed.amount, amount_max: parsed.amount_max)
      elsif table == :ingredients
        row.update_columns(note: [ row.amount_text.strip, row.note ].compact_blank.join("; "))
      end
    end
  end
end
