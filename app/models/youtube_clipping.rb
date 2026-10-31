# One transcript file written by the youtube-clippings downloader: YAML-ish
# frontmatter (title, url, channel, tags) followed by the transcript. Only
# videos from the Recipes playlist carry the `recipes` tag.
#
# The downloader writes a new file when a video's title changes, so the same
# video can appear twice — identify a clipping by its video id, never its
# filename.
class YoutubeClipping
  VIDEO_ID = %r{(?:youtube\.com/(?:watch\?(?:.*&)?v=|shorts/|embed/)|youtu\.be/)([\w-]{11})}

  attr_reader :path, :frontmatter, :body

  def self.recipes_in(dir)
    return [] if dir.blank? || !Dir.exist?(dir)

    Dir.glob(File.join(dir, "*.md")).sort.map { |path| new(path) }.select(&:recipe?)
  end

  def self.video_id(url) = url.to_s[VIDEO_ID, 1]

  def initialize(path, content = File.read(path, encoding: "UTF-8").scrub)
    @path = path
    @frontmatter, @body = split(content)
  end

  def recipe? = tags.include?("recipes") && video_id.present?

  # Stamped by the nanoclaw script this replaces; those were settled there.
  def handled_elsewhere? = frontmatter.key?("recipe_added")

  def video_id = self.class.video_id(frontmatter["url"])

  def source_url = "https://www.youtube.com/watch?v=#{video_id}"

  def image_url = "https://i.ytimg.com/vi/#{video_id}/hqdefault.jpg"

  def title = frontmatter["title"]

  def channel = frontmatter["channel"]

  def tags
    frontmatter["tags"].to_s.delete("[]").split(",").map { |tag| tag.strip.downcase }
  end

  private

  # Line-by-line rather than YAML.load: titles carry colons and quotes the
  # downloader doesn't always escape, and one bad file must not stop a scan.
  def split(content)
    match = content.match(/\A---\s*\n(.*?)\n---\s*\n?(.*)\z/m)
    return [ {}, content ] unless match

    fields = match[1].lines.filter_map do |line|
      key, value = line.split(":", 2)
      [ key.strip, value.strip.delete_prefix('"').delete_suffix('"') ] if value && key.match?(/\A\w+\z/)
    end
    [ fields.to_h, match[2] ]
  end
end
