# A decimal column casts "to taste" to 0, so text that isn't an amount must be
# caught here and kept in `amount_words`, never handed to `super`.
module HasAmount
  extend ActiveSupport::Concern

  included do
    attr_reader :amount_words
  end

  def amount=(value)
    @amount_words = nil
    self.amount_max = nil

    case value
    when nil, Numeric then super
    else
      text = value.to_s.strip
      parsed = IngredientAmount.parse(text)
      @amount_words = text.presence unless parsed
      super(parsed&.amount)
      self.amount_max = parsed&.amount_max
    end
  end

  def display_amount = IngredientAmount.format(amount, amount_max)
end
