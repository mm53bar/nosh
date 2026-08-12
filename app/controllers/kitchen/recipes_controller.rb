module Kitchen
  class RecipesController < BaseController
    before_action :set_recipe

    def show
    end

    # The kitchen's own "made it", rather than a link to RecipesController#made
    # — that one redirects to the main app's recipe page, which would strand
    # the kiosk outside the kitchen chrome with no back button.
    #
    # JSON only, and called by fetch() rather than submitted as a form. The
    # kiosk's Home Assistant page is a different *site* from nosh, so the
    # session cookie never arrives and there's no CSRF token to submit with;
    # JSON requests are already exempt from forgery protection. See
    # docs/adr/20260812-framed-by-home-assistant.md.
    def made
      @recipe.update!(last_made_on: Date.current)
      render json: { last_made_on: @recipe.last_made_on, label: helpers.last_made_label(@recipe) }
    end

    private

      def set_recipe
        @recipe = Recipe.includes(:ingredients, :steps).find(params[:id])
      end
  end
end
