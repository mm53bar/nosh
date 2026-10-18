# What voice can do to the shopping list, and what it says back. Voice can only
# flip tabs: anything not on the board is refused and pointed at nosh, never
# added — a fixed vocabulary is what makes a mishearing audible. The replies
# are written here rather than in Home Assistant so the wording sits next to
# the rules it describes. See docs/adr/20261018-shopping-list-is-a-staples-board.md.
class ShoppingBoard
  Result = Struct.new(:matches, :speech, keyword_init: true)

  def initialize(matcher: StapleMatcher.new)
    @matcher = matcher
  end

  def need(text)
    matches = @matcher.match_all(text)
    flipped, already = matches.select(&:staple?).map(&:staple).uniq.partition { |staple| !staple.needed? }
    flipped.each { |staple| staple.update!(needed: true) }

    speech = []
    speech << "Added #{names(flipped)}." if flipped.any?
    speech << "#{names(already).upcase_first} #{already.one? ? "is" : "are"} already on the list." if already.any?
    Result.new(matches: matches, speech: (speech + group_and_unknown_speech(matches)).join(" "))
  end

  def have(text)
    matches = @matcher.match_all(text)
    crossed, absent = matches.select(&:staple?).map(&:staple).uniq.partition(&:needed?)
    crossed.each { |staple| staple.update!(needed: false) }

    speech = []
    speech << "Crossed off #{names(crossed)}." if crossed.any?
    speech << "#{names(absent).upcase_first} #{absent.one? ? "wasn't" : "weren't"} on the list." if absent.any?
    Result.new(matches: matches, speech: (speech + group_and_unknown_speech(matches)).join(" "))
  end

  def read_back
    needed = Staple.needed.joins(:aisle).order("aisles.position", :position).map(&:name)
    written = WriteIn.open.map(&:name)
    this_week = ShoppingListItem.this_week.where(checked: false).count

    return "Nothing's on the list." if needed.empty? && written.empty? && this_week.zero?

    speech = []
    speech << "You need #{needed.to_sentence}." if needed.any?
    speech << "Written in: #{written.to_sentence}." if written.any?
    speech << "This week's meals need #{this_week} #{this_week == 1 ? "more thing" : "more things"}." if this_week.positive?
    speech.join(" ")
  end

  private

  def names(staples) = staples.map(&:name).to_sentence

  def group_and_unknown_speech(matches)
    speech = matches.select(&:group?).uniq(&:group).map do |match|
      "Which #{match.group}? #{match.choices.map(&:name).to_sentence(two_words_connector: " or ", last_word_connector: " or ").upcase_first}."
    end

    unknown = matches.select(&:unknown?)
    unknown.each do |match|
      line = "#{match.input.strip.upcase_first} isn't on the board"
      line += ", closest is #{match.closest.name}" if match.closest
      speech << "#{line}."
    end
    speech << "You can add #{unknown.one? ? "it" : "them"} in nosh." if unknown.any?
    speech
  end
end
