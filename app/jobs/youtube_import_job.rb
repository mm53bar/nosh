# Daily: turns new transcripts from the YouTube Recipes playlist into recipe
# candidates for someone to review. The youtube-clippings downloader writes
# them to a folder nosh has mounted read-only (YOUTUBE_CLIPPINGS_PATH); what's
# been seen is tracked here, by video, never by writing back to the files.
#
# Ollama is pay-as-you-go, so a run extracts at most PER_RUN transcripts and
# leaves the rest queued for the next one. Not configured (no folder or no
# LLM) → does nothing, keeping dev and CI quiet.
class YoutubeImportJob < ApplicationJob
  queue_as :default
  # Overlapping runs would read, and pay for, the same queued videos twice.
  limits_concurrency key: "youtube_import", duration: 30.minutes, on_conflict: :discard

  PER_RUN = 5

  # dir: and llm: are injectable so tests can point them at fixtures.
  def perform(dir: ENV["YOUTUBE_CLIPPINGS_PATH"], llm: LlmClient.from_env)
    return if dir.blank? || !llm.configured?

    queue_new_clippings(dir)
    RecipeCandidate.queued.order(:created_at).limit(PER_RUN).each do |candidate|
      candidate.extract!(llm)
    rescue LlmClient::Unavailable => e
      Rails.logger.warn("YoutubeImportJob: LLM unavailable, stopping this run: #{e.message}")
      break
    end
  end

  private

  def queue_new_clippings(dir)
    YoutubeClipping.recipes_in(dir).reject(&:handled_elsewhere?).uniq(&:video_id).each do |clipping|
      next if RecipeCandidate.exists?(source_url: clipping.source_url)
      next if Recipe.where("source_url LIKE ?", "%#{clipping.video_id}%").exists?

      RecipeCandidate.create!(origin: "youtube", source_url: clipping.source_url, title: clipping.title,
                              source_text: clipping.body, image_url: clipping.image_url)
    rescue ActiveRecord::RecordNotUnique
      next
    end
  end
end
