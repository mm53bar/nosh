# Pushes nosh's shopping list into a Home Assistant to-do list.
#
# Additive only, on purpose. That list is live household state — people add to
# it by voice and phone continuously, and nosh is never its only writer. So:
# no clearing, no bulk replace, no removing what someone else put there. The
# worst this can do is leave a stale item behind, which beats deleting the
# Advil someone asked for while unpacking groceries.
#
# `todo.add_item` does not deduplicate — adding "olive oil" twice yields two
# entries — so every publish reads the list first and diffs case-insensitively.
class ShoppingListPublisher
  Result = Struct.new(:added, :skipped, :configured, keyword_init: true) do
    def configured? = configured
    def any_added? = added.any?
    def summary
      return "Home Assistant is not configured." unless configured?

      "#{added.size} added, #{skipped.size} already on the list."
    end
  end

  def initialize(todo: HomeAssistantTodo.from_env, items: nil)
    @todo = todo
    @items = items
  end

  # What a publish would do, without writing anything. The button shows this
  # before touching a screen in someone's kitchen.
  def preview
    return unconfigured_result unless @todo.configured?

    already = existing_summaries
    new_items, known = items.partition { |item| already.exclude?(item.name.to_s.downcase.strip) }
    Result.new(added: new_items.map(&:name), skipped: known.map(&:name), configured: true)
  end

  def publish
    return unconfigured_result unless @todo.configured?

    # Bought items go before the diff is taken, so last week's purchases don't
    # suppress this week's genuine need for the same ingredient. Everything left
    # is outstanding, which is exactly what "already on the list" should mean.
    #
    # This does NOT make re-publishing the same plan idempotent: anything bought
    # since the last publish is cleared and then re-added. Publish once per plan.
    @todo.clear_completed

    already = existing_summaries
    added = []
    skipped = []

    items.each do |item|
      if already.include?(item.name.to_s.downcase.strip)
        skipped << item.name
        next
      end

      @todo.add(summary: summary_for(item), description: description_for(item))
      # Guards against a list that already contains the same ingredient twice
      # under different units, which would otherwise be added twice here.
      already << item.name.to_s.downcase.strip
      added << item.name
    end

    Result.new(added: added, skipped: skipped, configured: true)
  end

  private

  def items = @items ||= ShoppingListItem.where(checked: false).order(:name)

  def existing_summaries = @todo.open_items.map { |item| item.summary.to_s.downcase.strip }.to_set

  # The name alone. It is read at a glance in an aisle and spoken by the voice
  # readback, so quantity and provenance go in the description instead — see
  # docs/adr/20260815-ingredient-name-is-the-shopping-label.md.
  #
  # Where the list can't hold a description, the quantity folds into the name
  # rather than being lost.
  def summary_for(item)
    return item.name if @todo.supports_description? || quantity(item).blank?

    "#{item.name} (#{quantity(item)})"
  end

  def description_for(item) = markdown_safe([ quantity(item), item.source ].compact_blank.join(" · ")).presence

  # The description is rendered as markdown by the Home Assistant card, so a
  # recipe title starting with "#" would come out as a heading and a "*" would
  # italicise the rest of the line. Recipe titles come from whatever a source
  # site put in its JSON-LD, so this is not hypothetical for long.
  #
  # These characters are removed rather than backslash-escaped: escaping only
  # works if the renderer honours it, and a stray footnote asterisk carries no
  # meaning worth preserving on a shopping list.
  def markdown_safe(text)
    text.gsub(/[*_`~\[\]]/, "").sub(/\A[#>\-+\s]+/, "").strip
  end

  def quantity(item) = [ item.amount, item.unit ].compact_blank.join(" ")

  def unconfigured_result = Result.new(added: [], skipped: [], configured: false)
end
