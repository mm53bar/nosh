# JSON only: the ingredient audit is the one writer. Posting a variant that
# already has an alias re-points it rather than failing, so the audit can apply
# its whole decision log on every run.
class IngredientAliasesController < ApplicationController
  def index
    render json: IngredientAlias.order(:variant).map { |ingredient_alias| as_json_row(ingredient_alias) }
  end

  def create
    attributes = params.require(:ingredient_alias).permit(:variant, :canonical)
    ingredient_alias = IngredientAlias.find_or_initialize_by(variant: IngredientAlias.key(attributes[:variant]))
    created = ingredient_alias.new_record?

    if ingredient_alias.update(canonical: attributes[:canonical])
      render json: as_json_row(ingredient_alias).merge(renamed: ingredient_alias.renamed), status: created ? :created : :ok
    else
      render json: { errors: ingredient_alias.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    IngredientAlias.find(params[:id]).destroy!
    head :no_content
  end

  private

  def as_json_row(ingredient_alias) = ingredient_alias.slice(:id, :variant, :canonical)
end
