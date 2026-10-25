# See docs/adr/20261025-amounts-are-stored-as-numbers.md.
class IngredientAmount
  GLYPHS = {
    Rational(1, 2) => "½", Rational(1, 3) => "⅓", Rational(2, 3) => "⅔",
    Rational(1, 4) => "¼", Rational(3, 4) => "¾",
    Rational(1, 5) => "⅕", Rational(2, 5) => "⅖", Rational(3, 5) => "⅗", Rational(4, 5) => "⅘",
    Rational(1, 6) => "⅙", Rational(5, 6) => "⅚",
    Rational(1, 8) => "⅛", Rational(3, 8) => "⅜", Rational(5, 8) => "⅝", Rational(7, 8) => "⅞"
  }.freeze
  GLYPH_VALUES = GLYPHS.invert.freeze
  GLYPH = "[#{GLYPHS.values.join}]".freeze

  # Kitchen measures a stored number may be snapped to for display. Fifths are
  # left out: a decimal like 0.4 is far more often metric than two-fifths.
  SNAP_DENOMINATORS = [ 1, 2, 3, 4, 6, 8 ].freeze
  SNAP_TOLERANCE = Rational(1, 100)

  NUMBER = %r{\d+\s+(?:and\s+)?\d+/\d+|\d+/\d+|\d*\s*#{GLYPH}|\d*\.\d+|\d+}
  RANGE = /\A(#{NUMBER})(?:\s*(?:[-–—]|\bto\b)\s*(#{NUMBER}))?\z/i

  Parsed = Struct.new(:amount, :amount_max)

  def self.parse(text)
    match = text.to_s.strip.match(RANGE)
    return nil unless match

    low = number(match[1])
    high = match[2] && number(match[2])
    return nil if low.nil? || (match[2] && high.nil?)

    if high.nil? || high == low
      Parsed.new(decimal(low), nil)
    elsif high > low
      Parsed.new(decimal(low), decimal(high))
    elsif high < 1 && low.denominator == 1
      # "1-1/4" is how some sites write a mixed number, not a range down to ¼.
      Parsed.new(decimal(low + high), nil)
    end
  end

  def self.format(amount, amount_max = nil)
    return nil if amount.nil?
    return format_number(amount) if amount_max.nil? || amount_max <= amount

    "#{format_number(amount)}–#{format_number(amount_max)}"
  end

  def self.format_number(value)
    exact = value.to_r
    SNAP_DENOMINATORS.each do |denominator|
      snapped = Rational((exact * denominator).round, denominator)
      next if (exact - snapped).abs >= SNAP_TOLERANCE

      whole, part = snapped.divmod(1)
      return whole.to_s if part.zero?
      return "#{whole unless whole.zero?}#{GLYPHS.fetch(part)}"
    end
    Kernel.format("%.2f", exact).sub(/\.?0+\z/, "")
  end

  def self.number(text)
    case text.strip
    when %r{\A(\d+)\s+(?:and\s+)?(\d+)/(\d+)\z} then fraction(Regexp.last_match(2), Regexp.last_match(3), whole: Regexp.last_match(1))
    when %r{\A(\d+)/(\d+)\z} then fraction(Regexp.last_match(1), Regexp.last_match(2))
    when /\A(\d*)\s*(#{GLYPH})\z/ then Regexp.last_match(1).to_i + GLYPH_VALUES.fetch(Regexp.last_match(2))
    else text.strip.to_r
    end
  end

  def self.fraction(numerator, denominator, whole: 0)
    return nil if denominator.to_i.zero?

    whole.to_i + Rational(numerator.to_i, denominator.to_i)
  end

  def self.decimal(value) = BigDecimal(value, 12).round(4)

  private_class_method :number, :fraction, :decimal
end
