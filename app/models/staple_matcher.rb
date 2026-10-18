# Resolves what someone said or typed to a tab on the board. Voice, the typed
# box and the meal plan's markers all go through here, so "add butter" means
# the same thing however it arrives.
#
# The answer is one of three kinds:
#   :staple   one tab — flip it
#   :group    a word like "cheese" that names several tabs; never flips anything
#   :unknown  not on the board, with the closest tab if one is close
class StapleMatcher
  Match = Struct.new(:input, :kind, :staple, :group, :choices, :closest, keyword_init: true) do
    def staple? = kind == :staple
    def group? = kind == :group
    def unknown? = kind == :unknown
  end

  LEADING_WORDS = %w[a an the some more].freeze
  CLOSE_ENOUGH = 0.6

  # Lowercase, articles dropped, last word singular: "Some Potatoes" and
  # "potato" are the same key. Only the last word is singularised, because that
  # is the noun — "olive oils" is "olive oil", but "brussels sprouts" must not
  # lose the s from brussels.
  def self.key(text)
    words = text.to_s.downcase.tr("-", " ").gsub(/[^a-z0-9' ]/, " ").split
    words.shift while words.size > 1 && LEADING_WORDS.include?(words.first)
    return "" if words.empty?

    words[-1] = singular(words[-1])
    words.join(" ")
  end

  # Not ActiveSupport's singularize, whose Latin rules turn "feta" into "fetum"
  # and "pasta" into "pastum". English plurals only; both sides of every
  # comparison go through this, so it needs to be consistent, not perfect.
  def self.singular(word)
    case word
    when /(?:ss|us|is)\z/ then word
    when /ies\z/ then word.delete_suffix("ies") + "y"
    when /(?:o|ch|sh|x|ss)es\z/ then word.delete_suffix("es")
    when /s\z/ then word.delete_suffix("s")
    else word
    end
  end

  def initialize(staples = Staple.joins(:aisle).order("aisles.position", :position).to_a)
    @by_key = {}
    @by_compact = {}
    staples.each do |staple|
      staple.keys.each do |key|
        @by_key[key] ||= staple
        @by_compact[key.delete(" ")] ||= staple
      end
    end
    @groups = staples.select(&:group_name).group_by { |staple| self.class.key(staple.group_name) }
  end

  def match(text)
    key = self.class.key(text)

    if (staple = @by_key[key] || @by_compact[key.delete(" ")] || qualified(key))
      Match.new(input: text, kind: :staple, staple: staple)
    elsif (members = @groups[key])
      Match.new(input: text, kind: :group, group: members.first.group_name, choices: members)
    else
      Match.new(input: text, kind: :unknown, closest: closest(key))
    end
  end

  # Several items in one breath — "butter and eggs", "milk, bread and jam". The
  # whole phrase is tried first, so a tab whose name contains "and" still wins.
  def match_all(text)
    whole = match(text)
    return [ whole ] unless whole.unknown?

    parts = text.to_s.split(/\s*(?:,|&|\band\b)\s*/i).compact_blank
    parts.size > 1 ? parts.map { |part| match(part) } : [ whole ]
  end

  private

  # "feta cheese" is the feta tab: a member's name followed by its group word.
  # Recipes name cheeses this way far more often than the board does.
  def qualified(key)
    @groups.each do |group, members|
      next unless key.end_with?(" #{group}")

      staple = @by_key[self.class.key(key.delete_suffix(" #{group}"))]
      return staple if members.include?(staple)
    end
    nil
  end

  def closest(key)
    return nil if key.blank?

    best, score = @by_key.map { |candidate, staple| [ staple, similarity(key, candidate) ] }.max_by(&:last)
    best if score && score >= CLOSE_ENOUGH
  end

  # A tab whose every word appears in the input is a strong hint ("almond milk"
  # → milk). Otherwise edit distance relative to length, ignoring spaces, plus a
  # little for a shared start. A mishearing keeps the first sound, so nothing
  # with a different first letter is offered — "tomatoes" must not suggest
  # potatoes just because they rhyme.
  def similarity(input, candidate)
    return 0.9 if (candidate.split - input.split).empty?

    a = input.delete(" ")
    b = candidate.delete(" ")
    return 0.0 unless a[0] == b[0]

    prefix = a.chars.zip(b.chars).take_while { |x, y| x == y }.size
    1.0 - levenshtein(a, b).to_f / [ a.length, b.length ].max + 0.1 * [ prefix, 4 ].min / 4
  end

  def levenshtein(a, b)
    previous = (0..b.length).to_a
    a.each_char.with_index(1) do |char_a, i|
      current = [ i ]
      b.each_char.with_index(1) do |char_b, j|
        current << [ previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (char_a == char_b ? 0 : 1) ].min
      end
      previous = current
    end
    previous.last
  end
end
