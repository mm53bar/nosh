class Ingredient < ApplicationRecord
  include HasAmount

  belongs_to :recipe

  validates :name, presence: true

  # API clients post whatever a source page gave them — "1 (14 ounce) package
  # extra-firm tofu, drained" arrives as a single string. Splitting that is
  # nosh's job, not every caller's: the alternative is each writer carrying its
  # own parser and the collection re-dirtying every time one of them runs.
  #
  # Deliberately narrow:
  #   * create only — an update is someone deciding, and re-parsing would undo it
  #   * only when no note was supplied — a caller that split it already is trusted
  #   * amount and unit are filled only when empty, so nothing is ever discarded
  #
  # See docs/adr/20260815-ingredient-name-is-the-shopping-label.md.
  before_validation :remember_original_text, on: :create
  before_validation :split_name_into_note, on: :create
  before_validation :apply_alias, on: :create
  before_validation :keep_amount_words_in_note

  def quantity(scale = 1) = [ display_amount(scale), unit ].compact_blank.join(" ")

  # Written once, on create: it's what a changed parser gets re-run against, so
  # an edit must never overwrite it.
  def original_text=(text)
    super if new_record?
  end

  private

  def remember_original_text
    return if original_text.present?

    line = [ amount_as_written || display_amount, unit, name ].compact_blank.join(" ")
    self.original_text = [ line, note ].compact_blank.join(", ").presence
  end

  def split_name_into_note
    return if note.present? || name.blank?

    parsed = IngredientLine.parse(name)
    return if parsed.name.blank?

    self.name = parsed.name
    self.note = parsed.note
    self.amount = parsed.amount if amount.blank?
    self.unit = parsed.unit if unit.blank?
  end

  def apply_alias
    self.name = IngredientAlias.canonical_for(name) || name
  end

  def keep_amount_words_in_note
    return if amount_words.blank?

    self.note = [ amount_words, note ].compact_blank.join("; ")
    @amount_words = nil
  end
end
