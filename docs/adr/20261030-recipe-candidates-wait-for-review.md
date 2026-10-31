# 20261030 — Recipes found automatically wait for review as RecipeCandidates

Supersedes [`20260809-no-settings-recipe-discovery-is-nanoclaws-job.md`](20260809-no-settings-recipe-discovery-is-nanoclaws-job.md)
for YouTube imports. Its "no Settings model" decision still stands.

## Context

Videos saved to the household's YouTube Recipes playlist are downloaded as transcript files by
the `youtube-clippings` container on Jumbo. A nanoclaw script turned them into recipes with an
LLM and added them straight to the collection. It had silently done nothing since at least
2026-09-25: the NFS mount it read from was gone, and it posted to the old Express app's
`/api/recipes` rather than to nosh.

On 2026-10-25 nanoclaw stopped adding recipes at all, after its recipe-discovery job let five
fish dinners into a vegetarian household's collection. Automatic adding was the failure, not
the source.

## Decision

nosh reads the transcripts itself and never adds one without a person.

- **`YoutubeImportJob`** runs daily (`config/recurring.yml`). It reads the folder at
  `YOUTUBE_CLIPPINGS_PATH`, mounted read-only, and keeps every `recipes`-tagged video it hasn't
  seen. It skips any video already in the collection, matched by video id so `youtu.be` and
  `watch?v=` links agree, and files the nanoclaw script stamped `recipe_added:`. The downloader
  writes a new file when a title changes, so a video is identified by its id, never its filename.
- **`RecipeCandidate`** holds each one: the transcript, the model's proposal, and a status
  (`queued` → `ready` or `failed` → `accepted` or `discarded`). It is a separate model rather than a
  flag on `Recipe`, so nothing that reads recipes (the list, `/recipes.json`, the Saturday slate)
  can pick up an unreviewed one. The name is generic on purpose: an RSS feed or another source
  would add rows with a different `origin`.
- **The proposal is shaped like a schema.org/Recipe node**, so `RecipeImporter#build` turns it
  into a recipe exactly as it does an imported page. Ingredient lines, amounts, aliases and
  `original_text` all follow the existing rules.
- **The LLM** is any OpenAI-compatible endpoint, configured by `LLM_BASE_URL` / `LLM_MODEL` /
  `LLM_API_KEY`. `LlmClient` is copied from wander. Ollama Cloud is pay-as-you-go from 2026-11-09,
  so each video gets one completion, at most three if the answer is unusable. An outage costs no
  attempt, and a run reads at most five videos.
- **Review is tsundoku's pattern.** An amber banner under the header lists what's waiting
  (`ready` or `failed`). **Review** opens the normal recipe form, filled from the proposal, with
  the transcript below it. **Add to recipes** saves it and attaches the video's thumbnail unless
  a photo was uploaded. **Discard** keeps the row, so the video is never suggested again.
- **Vegetarian check, twice.** The model lists the lines it thinks aren't vegetarian, and a word
  check (`RecipeCandidate::NOT_VEGETARIAN`) flags any line it catches. Either one puts a warning
  on the review. Neither one hides the candidate, so a false alarm costs a glance and a miss is
  still seen by a person.

## Consequences

- nanoclaw's `youtube-recipes.timer` can be retired; it was the last nanoclaw job writing
  recipes.
- The container needs the clippings folder mounted and the LLM env set. Without either, the job
  does nothing.
- Transcripts the downloader never got (YouTube rate-limits subtitle downloads) never show up.
  That's the downloader's problem to fix, not nosh's.
- "Check for new videos" on the review page runs the job on demand, which can cost a few model
  calls.

## Alternatives considered

- **Pasting a YouTube link into the import box.** It keeps a person on every add without a queue,
  but it only works for a video someone remembers to paste. Chosen against by the operator: the playlist
  is already the place where a video gets picked.
- **A `needs-review` flag or tag on `Recipe`.** It needs no new model, but every query that reads
  recipes, including nanoclaw's slate builder, would have to exclude it. Missing one is how the
  fish got in.
- **Writing `recipe_added:` back to the clipping files**, as the nanoclaw script did. That needs
  the notes vault mounted read-write and mixes nosh's state into someone else's files.
- **An Unsplash image fallback**, as the nanoclaw script had. The video's own thumbnail is the
  dish.
