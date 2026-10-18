class StaplesController < ApplicationController
  before_action :set_staple, only: [ :edit, :update, :destroy ]

  def index
    @aisles = Aisle.order(:position).includes(:staples)
  end

  def create
    @staple = Staple.new(staple_params)
    if @staple.save
      respond_to do |format|
        format.html { redirect_to staples_path, notice: "Added #{@staple.name}." }
        format.json { render json: staple_json(@staple), status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to staples_path, alert: @staple.errors.full_messages.to_sentence }
        format.json { render json: { errors: @staple.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    if @staple.update(staple_params)
      respond_to do |format|
        format.html { redirect_to staples_path, notice: "Saved #{@staple.name}." }
        format.json { render json: staple_json(@staple) }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @staple.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @staple.destroy!
    respond_to do |format|
      format.html { redirect_to staples_path, notice: "Removed #{@staple.name}." }
      format.json { head :no_content }
    end
  end

  # Voice: "add milk", "we're out of eggs". Answers 200 whatever was matched —
  # a refusal is a successful answer with something to say, not an error.
  def need
    render json: board_json(ShoppingBoard.new.need(params.require(:item)))
  end

  # Voice: "we've got milk".
  def have
    render json: board_json(ShoppingBoard.new.have(params.require(:item)))
  end

  private

  def set_staple
    @staple = Staple.find(params[:id])
  end

  def staple_params
    params.require(:staple).permit(:name, :aisle_id, :aisle_name, :position, :needed, :group_name, :note, :aliases_text, aliases: [])
  end

  def staple_json(staple)
    staple.as_json(only: [ :id, :name, :needed, :group_name, :note, :aliases, :position ]).merge(aisle: staple.aisle.name)
  end

  def board_json(result)
    {
      speech: result.speech,
      matches: result.matches.map do |match|
        { input: match.input, kind: match.kind, staple: match.staple&.name, needed: match.staple&.needed,
          choices: match.choices&.map(&:name), closest: match.closest&.name }
      end
    }
  end
end
