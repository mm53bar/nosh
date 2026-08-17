# 20260817 — The kitchen screen takes its theme from the URL

## Context

The kitchen wall screen (`/kitchen`, see `20260812-framed-by-home-assistant.md`) is a bright white
page — `stone-50` ground, white cards — sitting inside a Home Assistant dashboard that is themed
dark. In a kitchen at night it reads as a lamp on the wall rather than as one panel among several.

Home Assistant owns the dashboard and therefore knows which palette it wants; nosh doesn't. The
Echo Show is a first-generation device on LineageOS, so whether its WebView reports a colour scheme
to CSS at all is unverified.

## Decision

`?theme=` on any `/kitchen` URL, with three states:

| Value | Result |
|---|---|
| `dark` | forced dark |
| `light` | forced light |
| anything else, including absent | auto — `prefers-color-scheme`, falling back to light |

Auto is the default rather than light, and an unrecognised value falls back to auto rather than
erroring: a typo in a dashboard config should give a usable screen, and on a WebView that reports
nothing auto renders exactly the light screen this started as.

`Kitchen::BaseController` puts `theme-light` / `theme-dark` / `theme-auto` on `<html>` and adds the
param to `default_url_options`, so a theme set once on the embedded URL survives every tap — there
is no address bar on the kiosk to re-enter it with, and Home Assistant only ever sets it on the one
page it frames.

`dark:` is redefined as an opt-in variant keyed to those classes:

```css
@custom-variant dark {
  &:where(.theme-dark, .theme-dark *) { @slot; }
  @media (prefers-color-scheme: dark) {
    &:where(.theme-auto, .theme-auto *) { @slot; }
  }
}
```

Tailwind's stock `dark:` is a bare media query, which would flip *any* nosh page a laptop's OS
setting touched. Only the kitchen views carry dark classes, so that would half-style the browse UI.
Requiring an explicit `theme-auto` for the media branch means the variant can't fire on a page that
didn't ask for it.

The dark palette is verso's kiosk screen (`~/projects/wallpaper/verso`), the household's other
Echo Show page: `neutral-950` ground, `neutral-900` raised surfaces, `neutral-100` text,
`neutral-400`/`500` secondary, `neutral-800` borders. nosh's amber accent lifts to `amber-400` and
the "made it" button to `emerald-500` on near-black, since the light-mode `amber-700`/`emerald-600`
lose their contrast against it. Light mode is untouched.

## Consequences

- The two shared `.step.active` / `.step.done` rules go through custom properties, because the
  browse UI's show page uses the same classes with no theme class of its own. Adding a colour to
  that CSS means adding it in three scopes (`:root`, `:root.theme-dark`, and the media-gated
  `:root.theme-auto`), not one.
- Any new kitchen view needs a `dark:` for every colour utility it adds; there's no automatic
  inversion, and a missed one shows up as a white patch only on the wall screen.
- `color-scheme` is set per theme so the browser paints its own furniture — the two scroll panes
  above all — to match.
- Verified in headless Chrome with `--blink-settings=preferredColorScheme` that auto follows the
  emulated OS setting and that `/recipes` stays light under a dark preference.
- **The Echo Shows do report a colour scheme** — checked over ADB on both devices by the Home
  Assistant side on 2026-08-17, after this was written. So auto genuinely works on the hardware and
  is the right default; the explicit values are now for overriding the device rather than for
  working around it.

## Alternatives considered

- **A `theme=auto` value, with light as the no-param default.** Rejected as a distinction without a
  difference once auto degrades to light anyway: it costs the HA side a param to say what silence
  already says.
- **Semantic CSS custom properties for the whole palette** (`--surface`, `--text-muted`) with
  `bg-(--surface)` utilities. Cleaner in the abstract, but it rewrites every colour in the kitchen
  views into arbitrary values and puts the light palette — which is correct as it stands — at risk
  for no gain on a two-theme screen.
- **Letting Home Assistant restyle the iframe.** Not possible cross-origin, and the ADR above
  already establishes that nosh gets no cooperation from the parent page.
