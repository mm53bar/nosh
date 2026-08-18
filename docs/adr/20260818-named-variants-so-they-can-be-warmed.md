# 20260818 — Image variants are named, so something can warm them

## Context

The browser recipe index rendered 127 cards, each `image_tag recipe.image` with no
`loading` attribute — the **original** blob, fetched immediately. A cold `/recipes` load was
about **18 MB over 127 requests** into CSS boxes roughly 360px wide, while 118 of the 127
originals were wider than 720px. Most of those bytes were decoded and discarded.

The two kitchen views had already got the sizing right, with `resize_to_fill` variants and
`loading: "lazy"`. But their sizes lived in `KITCHEN_CARD_VARIANT` / `KITCHEN_CORNER_VARIANT`
hashes in `KitchenHelper` and were passed inline as `image.variant(**hash)`.

An inline variant is one **nothing can warm.** Active Storage keys a rendition by the
transformation it was asked for, so a variant that only exists as an anonymous hash at a call
site is invisible to any backfill task — no task can enumerate what it doesn't know about.
Active Storage generates it on first request and caches it after, which is fine right up until
the first request is expensive.

It was expensive. The helper's comment claimed the stored photos were "full-resolution (up to
~200 KB each)". Measured 2026-08-18, the collection was 46.4 MB across 127 images with a median
of 140 KB — but the largest was **8192×5464 at 14.9 MB**, and a second was 7.9 MB. Generating a
480×270 fill from a 44-megapixel JPEG is seconds of libvips work holding one of only **three**
Puma threads. verso measured the same operation at 42 seconds for a cold variant of a very large
original on this NAS. Only 15 rendition records existed against roughly 254 the kitchen views
can ask for, so most kitchen card loads were still paying that first-request cost.

## Decision

**Declare every variant as a named, `preprocessed: true` variant on the `has_one_attached`
block**, and reference it by name (`recipe.image.variant(:kitchen_card)`):

- `:card` — 720×405, the browser index
- `:kitchen_card` — 480×270, unchanged size
- `:kitchen_corner` — 562×316, unchanged size

Named variants are enumerable, so `rake images:warm` can backfill the ones attached before this
existed; `preprocessed: true` means everything attached from now on is generated on attach and
never on a request. The browser card also gets `loading: "lazy"` and `decoding: "async"`, taking
a cold index from 127 immediate requests to roughly the nine above the fold.

The `variable?` fallback that `KitchenHelper` already had is kept, moved to
`ApplicationHelper#recipe_image_source` so all three call sites share one copy. Active Storage
raises rather than degrading when a blob can't be transformed, and recipes are imported from
arbitrary web pages, so this is not hypothetical.

Separately, the two outlier originals were re-encoded to 1600px at quality 82 — 22.8 MB to
1.4 MB, taking the whole collection from 46.4 MB to 23.9 MB. Originals kept outside this repo,
in the operator workspace.

## Consequences

The index serves roughly a third of the bytes it did, most of them deferred until scroll. Kitchen
screens stop paying cold-variant cost once `images:warm` has run. Adding a fourth size now means
declaring it on the model rather than inventing a hash at a call site, which is the constraint
that makes warming possible at all.

`preprocessed: true` costs work on every attach, including recipe imports. That is the right
trade — an import already waits on a network fetch, and it moves cost off the request path of a
kitchen screen someone is standing in front of.

`rake images:warm` is idempotent and safe to re-run; it is not automatic, because it is a
backfill for a one-time gap, not an ongoing job.

## Alternatives rejected

**Proxy mode (`resolve_model_to_route = :rails_storage_proxy`) to skip the 302.** This looks like
an upgrade and is a trap. Active Storage's proxy controller includes `ActionController::Live`,
which deletes `Content-Length` on first write, hands the body to a second thread that checks out
a **second database connection**, and is measurably slower (verso: p90 516ms for a 40 KB
thumbnail, versus a flat 165ms for 2.3 MB without streaming). It broke verso twice in one day.
nosh is on Rails' default `:rails_storage_redirect` and must stay there.

**Leaving the originals and relying on variants alone.** The 14.9 MB file would still make every
first variant generation slow, and it is the one image that makes a warm pass expensive.

**Keeping the inline hashes and adding a warmer that hardcodes the same hashes.** Two copies of
each size that must agree, with no way to detect drift.
