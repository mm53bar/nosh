class Ingredient < ApplicationRecord
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
  before_validation :split_name_into_note, on: :create

  private

  def split_name_into_note
    return if note.present? || name.blank?

    parsed = IngredientLine.parse(name)
    return if parsed.name.blank?

    self.name = parsed.name
    self.note = parsed.note
    self.amount = parsed.amount if amount.blank?
    self.unit = parsed.unit if unit.blank?
  end
end
