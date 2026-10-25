# A decimal column casts "to taste" to 0, so text that isn't an amount must be
# caught here and kept in `amount_words`, never handed to `super`.
module HasAmount
  extend ActiveSupport::Concern

  included do
    attr_reader :amount_words, :amount_as_written
  end

  def amount=(value)
    @amount_words = nil
    @amount_as_written = nil
    self.amount_max = nil

    case value
    when nil, Numeric then super
    else
      text = value.to_s.strip
      @amount_as_written = text.presence
      parsed = IngredientAmount.parse(text)
      @amount_words = text.presence unless parsed
      super(parsed&.amount)
      self.amount_max = parsed&.amount_max
    end
  end

  def display_amount(scale = 1) = IngredientAmount.format(amount && amount * scale, amount_max && amount_max * scale)
end
