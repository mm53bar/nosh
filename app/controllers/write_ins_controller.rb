# The typed box on the shopping list. It goes through the same matcher as
# voice, so typing a tab's name flips the tab instead of writing in a duplicate,
# and a group word ("cheese") asks which one. Only what matches nothing becomes
# a write-in — the one thing voice is never allowed to do.
class WriteInsController < ApplicationController
  def create
    name = params.require(:write_in).require(:name).to_s.squish
    match = StapleMatcher.new.match(name)

    if match.staple?
      match.staple.update!(needed: true)
      reply(kind: :staple, notice: "Flipped #{match.staple.name}.", staple: match.staple.name)
    elsif match.group?
      choices = match.choices.map(&:name)
      reply(kind: :group, alert: "Which #{match.group}? #{choices.to_sentence(last_word_connector: " or ").upcase_first}.",
            choices: choices, status: :unprocessable_entity)
    else
      write_in = WriteIn.open.find { |open| open.key == StapleMatcher.key(name) } || WriteIn.create!(name: name)
      reply(kind: :write_in, notice: "Wrote in #{write_in.name}.", id: write_in.id, promotable: write_in.promotable?)
    end
  end

  # Checking one off in the store.
  def update
    write_in = WriteIn.find(params[:id])
    bought = ActiveModel::Type::Boolean.new.cast(params.require(:write_in)[:bought])
    write_in.update!(bought_at: bought ? Time.current : nil)
    respond_to do |format|
      format.html { redirect_to shopping_list_path }
      format.json { render json: { id: write_in.id, bought: write_in.bought? } }
    end
  end

  def destroy
    WriteIn.find(params[:id]).destroy!
    respond_to do |format|
      format.html { redirect_to shopping_list_path }
      format.json { head :no_content }
    end
  end

  # Turns a name that keeps being written in into a tab, flipped on, because
  # it's on the list right now.
  def promote
    write_in = WriteIn.find(params[:id])
    staple = Staple.new(name: write_in.name, aisle_id: params.require(:aisle_id), needed: true)

    if staple.save
      write_in.destroy!
      respond_to do |format|
        format.html { redirect_to shopping_list_path, notice: "#{staple.name.upcase_first} has a tab now." }
        format.json { render json: { staple: staple.name }, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to shopping_list_path, alert: staple.errors.full_messages.to_sentence }
        format.json { render json: { errors: staple.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  private

  def reply(kind:, notice: nil, alert: nil, status: :ok, **json)
    respond_to do |format|
      format.html { redirect_to shopping_list_path, notice: notice, alert: alert }
      format.json { render json: json.merge(kind: kind, message: notice || alert), status: status }
    end
  end
end
