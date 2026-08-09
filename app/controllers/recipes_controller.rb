require "open-uri"

class RecipesController < ApplicationController
  before_action :set_recipe, only: [ :show, :edit, :update, :destroy, :made, :image ]

  def index
    @recipes = Recipe.includes(:tags, image_attachment: :blob).order(created_at: :desc)

    respond_to do |format|
      format.html { load_facets }
      format.json do
        @recipes = @recipes.where("title LIKE ?", "%#{params[:search]}%") if params[:search].present?
        @recipes = @recipes.joins(:tags).where(tags: { name: params[:tag] }) if params[:tag].present?
        @recipes = @recipes.where(cuisine: params[:cuisine]) if params[:cuisine].present?
        @recipes = @recipes.where(rating: nil) if params[:unrated] == "true"
        @recipes = @recipes.distinct
      end
    end
  end

  def show
  end

  def new
    @recipe = Recipe.new
    3.times { @recipe.ingredients.build }
    3.times { @recipe.steps.build }
  end

  def create
    @recipe = Recipe.new(recipe_params)
    if @recipe.save
      respond_to do |format|
        format.html { redirect_to @recipe, notice: "Recipe added." }
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @recipe.errors }, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    if @recipe.update(recipe_params)
      respond_to do |format|
        format.html { redirect_to @recipe, notice: "Recipe updated." }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @recipe.errors }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @recipe.destroy
    respond_to do |format|
      format.html { redirect_to recipes_path, notice: "Recipe deleted." }
      format.json { head :no_content }
    end
  end

  # Mirrors the old app's "mark as made today" action.
  def made
    @recipe.update!(last_made_on: Date.current)
    redirect_to @recipe, notice: "Marked as made today."
  end

  # Fetch-by-URL image ingestion (the raw-upload path is just the :image
  # param on #create/#update — Active Storage handles multipart uploads
  # natively, no separate endpoint needed for that case).
  def image
    uri = begin
      URI.parse(params[:url].to_s)
    rescue URI::InvalidURIError
      nil
    end

    if uri.nil? || !%w[http https].include?(uri.scheme)
      return respond_to do |format|
        format.html { redirect_to @recipe, alert: "Invalid image URL." }
        format.json { render json: { errors: [ "Invalid image URL" ] }, status: :unprocessable_entity }
      end
    end

    downloaded = URI.open(uri, "User-Agent" => "Mozilla/5.0 (compatible; nosh-bot)", redirect: true)
    @recipe.image.attach(io: downloaded, filename: File.basename(uri.path.presence || "image.jpg"))

    respond_to do |format|
      format.html { redirect_to @recipe, notice: "Image updated." }
      format.json { render :show }
    end
  end

  # Creates a recipe from a source page's embedded schema.org/Recipe JSON-LD
  # — the "add a recipe" entry point, replacing a manual-entry form button
  # (the old app never had one either; recipes are either migrated or
  # imported this way).
  def import
    result = RecipeImporter.new(params[:url]).call
    if result.success?
      redirect_to result.recipe, notice: "Imported \"#{result.recipe.title}\"."
    else
      redirect_to recipes_path, alert: result.error
    end
  end

  private

  # Sidebar facet option lists — computed from the loaded set rather than a
  # separate query, and kept in a fixed (not alphabetical) order for effort
  # and rating so the sidebar reads Quick→Involved, 5★→1★→Unrated.
  def load_facets
    @cuisines = @recipes.filter_map(&:cuisine).uniq.sort
    @meal_types = @recipes.filter_map(&:meal_type).uniq.sort
    @efforts = %w[Quick Medium Involved] & @recipes.filter_map { |r| helpers.recipe_effort(r) }.uniq
    @ratings = %w[5 4 3 2 1 unrated] & @recipes.map { |r| (r.rating || "unrated").to_s }.uniq
  end

  def set_recipe
    @recipe = Recipe.find(params[:id])
  end

  def recipe_params
    params.require(:recipe).permit(
      :title, :source_url, :description, :servings, :cuisine, :meal_type,
      :prep_time_minutes, :total_time_minutes, :notes, :rating, :last_made_on, :image,
      :tag_names_text, tag_names: [],
      ingredients_attributes: [ :id, :amount, :unit, :name, :position, :_destroy ],
      steps_attributes: [ :id, :instruction, :position, :_destroy ]
    )
  end
end
