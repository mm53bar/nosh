# Splits one freeform ingredient line — the shape schema.org/Recipe's
# `recipeIngredient` comes in, e.g. "1 (14 ounce) package extra-firm tofu,
# drained" — into amount, unit, name and note.
#
# The point of the split is that `name` is the *shopping label*: the words a
# person needs in front of them in a grocery aisle, and nothing else. Package
# sizes, prep instructions and asides are real information a cook wants, so
# they move to `note` rather than being dropped.
#
# This parser deliberately only moves what is structurally unambiguous:
# parentheticals, and a trailing clause that begins with a known preparation
# word. Anything needing judgment — substitutions ("white wine or vermouth"),
# lines covering several ingredients at once — is left in `name` untouched and
# left for `IngredientNameLinter` to flag for a human. Guessing here silently
# deletes options and allergen warnings; the old app's data has real examples
# of both. See docs/adr/20260815-ingredient-name-is-the-shopping-label.md.
class IngredientLine
  Parsed = Struct.new(:amount, :unit, :name, :note, keyword_init: true) do
    def to_attributes = { amount: amount, unit: unit, name: name, note: note }
  end

  QUANTITY = /[\d¼½¾⅓⅔⅛⅜⅝⅞.\/]+/
  FRACTION = /(?:\d+\/\d+|[¼½¾⅓⅔⅛⅜⅝⅞])/
  DASH = /[-–—]/
  # "2", "1 1/2", "2–3", "1 1/2 - 2"
  AMOUNT = /#{QUANTITY}(?:\s+#{FRACTION})?(?:\s*#{DASH}\s*#{QUANTITY}(?:\s+#{FRACTION})?)?/

  UNIT_WORDS = %w[
    cup cups tbsp tbsps tablespoon tablespoons tsp tsps teaspoon teaspoons
    g gram grams kg lb lbs pound pounds oz ounce ounces ml milliliter milliliters
    l liter liters clove cloves can cans piece pieces slice slices pinch pinches
    bunch bunches stalk stalks sprig sprigs package packages pkg jar jars bag bags
    box boxes bottle bottles head heads sheet sheets carton cartons packet packets
  ].freeze

  # Leading noise: a bullet copied from a list, or a hedge before the quantity
  # ("about 1 cup"). Stripped before parsing so the quantity is still found.
  LEADING_NOISE = /\A(?:[-–—•*]\s+|about\s+|approximately\s+)/i

  # A note that is only a price, left behind by budget recipe sites ("$0.26").
  PRICE_ONLY = /\A\$[\d.,]+\z/

  # A trailing clause is only treated as preparation when it *begins* with one
  # of these. The anchor matters: "water-packed tofu" must not be mistaken for
  # a "packed" instruction and torn off the end of the name.
  PREP_WORDS = %w[
    drained rinsed washed peeled trimmed seeded stemmed cored pitted halved shelled
    quartered chopped minced sliced diced cubed shredded grated crushed torn
    crumbled beaten whisked softened melted cooled warmed thawed strained
    divided reserved packed stirred toasted roasted rubbed
    finely roughly coarsely thinly thickly lightly freshly well
    cut broken separated
    optional preferably plus more extra for to at about approximately
    if such as room
  ].freeze

  PREP_CLAUSE = /\A(?:#{PREP_WORDS.join("|")})\b/i

  def self.parse(line) = new(line).parse

  def initialize(line)
    @raw = line.to_s.strip
  end

  def parse
    return Parsed.new(amount: nil, unit: nil, name: @raw, note: nil) if @raw.blank?

    text = @raw.sub(LEADING_NOISE, "")
    notes = []

    amount = take_amount(text)
    notes << take_multiplier_size(text)
    notes << take_leading_parenthetical(text)
    unit = take_unit(text)
    notes.concat(take_remaining_parentheticals(text))
    notes << take_prep_clause(text)

    name = tidy(text)

    # Nothing recognisable survived the split (e.g. "Salt and pepper to
    # taste" reduced to "Salt and pepper"): keep the original line whole
    # rather than shipping a fragment.
    return Parsed.new(amount: nil, unit: nil, name: @raw, note: nil) if name.blank?

    kept = notes.compact_blank.reject { |note| note.match?(PRICE_ONLY) }
    Parsed.new(amount: amount, unit: unit, name: name, note: kept.join("; ").presence)
  end

  private

  # A bare number is only joined to the next one when that one is a fraction
  # ("1 1/2") or across a dash ("2–3"), so "3 28-ounce cans" yields 3 and
  # leaves "28-ounce" alone. The atomic group is load-bearing: without it the
  # trailing lookahead would backtrack and match "2" out of "28-ounce".
  # The `%` in the lookahead keeps "100% powdered cacao" whole — a percentage
  # is part of the product name, not a quantity to pull out in front of it.
  def take_amount(text) = slice!(text, /\A(?>(#{AMOUNT}))(?![#{DASH.source[1..-2]}%])\s*/)

  # "2x 400g cans cannellini beans" — the count is the amount, the size after
  # the multiplier is a note, not a second quantity to leave in the name.
  def take_multiplier_size(text)
    return nil unless text.match?(/\Ax\s*#{QUANTITY}/)

    text.sub!(/\Ax\s*/, "")
    slice!(text, /\A(#{QUANTITY}\s*[a-zA-Z]+)\s+/)
  end

  # A package size sitting between the count and the noun: "1 (14 ounce) can".
  def take_leading_parenthetical(text) = slice!(text, /\A\(([^()]*)\)\s*/)

  def take_unit(text) = slice!(text, /\A(#{UNIT_WORDS.join("|")})\.?\s+/i)

  # Innermost-first and repeated, because the collection really does contain
  # doubled brackets — "Jalapeno ((seeds removed))" — and one pass over
  # `\([^)]*\)` leaves a stray bracket welded to the name.
  def take_remaining_parentheticals(text)
    found = []
    while text.gsub!(/\s*\(([^()]*)\)/) { found << Regexp.last_match(1).strip; "" }
    end
    found
  end

  def take_prep_clause(text)
    match = text.match(/,\s*(.+)\z/m)
    return nil unless match && match[1].match?(PREP_CLAUSE)

    text.slice!(match.begin(0)..)
    match[1].strip
  end

  # Removes a separator left dangling by an excised parenthetical, collapses
  # doubled whitespace, and drops trailing punctuation.
  def tidy(text)
    cleaned = text.gsub(/\s+/, " ").strip.sub(/\A[-—–,;]\s*/, "").sub(/[\s,;-]+\z/, "").strip
    # "Pinch of ground pepper" loses "Pinch" to the unit slot and would keep the
    # dangling "of"; a trailing "*" is a footnote marker from the source page.
    cleaned = cleaned.sub(/\A(?:of|de)\s+/i, "").sub(/\*+\z/, "").strip
    cleaned = cleaned.delete("()") if cleaned.count("(") != cleaned.count(")")
    cleaned.strip
  end

  # Deletes the first match from `text` in place and returns its capture.
  def slice!(text, pattern)
    match = text.match(pattern)
    return nil unless match

    text.slice!(match.begin(0)...match.end(0))
    match[1]&.strip
  end
end
