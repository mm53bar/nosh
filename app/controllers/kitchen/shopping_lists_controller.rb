module Kitchen
  # The staples board at counter distance, for the kiosk's Shopping view: every
  # tab on one screen, tapped to say "we're out", plus anything written in.
  # No typing (voice adds, and the kiosk keyboard is slow) and no "this week"
  # lines (the tabs those meals use carry a marker instead). See
  # docs/adr/20261031-kitchen-shopping-board.md.
  class ShoppingListsController < BaseController
    def show
      @aisles = Aisle.order(:position).includes(staples: :shopping_list_items).reject { |aisle| aisle.staples.empty? }
      @write_ins = WriteIn.open
    end
  end
end
