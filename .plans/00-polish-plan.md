# Plan A — make the Pixelize extension good-looking

**Goal.** Take the binary-backed scaffold from "it works" to "it looks and feels
like a first-class Aseprite tool" — a live before/after preview, a palette swatch
strip, theme-matching, polished layout, and a clean install — by adopting the
patterns of the best public extensions.

**This document is planning only.** It turns the research into a phased plan.

## Grounding

- Research: [`noelruault/research/aseprite-plugin/01-extension-quality.md`](https://github.com/noelruault/research/blob/main/aseprite-plugin/01-extension-quality.md)
  (manifest, lifecycle, sandbox, packaging, polish checklist) — all verified against
  the official `aseprite/api` docs and the C++ `security.cpp`.
- Verified UI capabilities and a working dialog sketch live in the research session
  notes; key facts restated below with their API gates.
- Current state: `package.json` + `pixelize.lua` (a basic `Dialog` that shells out
  to the binary and `app.open`s the result) + `Makefile` packaging. Functional, not
  yet polished.

## Exemplars to study / reverse-engineer (all public)

- **behreajj/AsepriteAddons** `dialogs/color/lchPicker.lua` — the best Canvas
  reference: multiple `dlg:canvas{}` in one non-modal dialog, theme-matched
  backgrounds (`app.theme.color.window_face`), `ctx.blendMode=SRC`,
  `ctx.antialias=false`, a custom swatch strip via `fillRect` + click hit-testing,
  `dlg:repaint()` wired into every handler.
- **Astropulse/K-Centroid-Aseprite** `extension.lua` (MIT) — clean resize controls:
  `separator{text=}` section headers, linked width/height px↔% fields, a "Lock
  Ratio" check, sliders. The exact resize+reduce control surface we need.
- **thkwznk/aseprite-scripts** `Magic Pencil/MagicPencilDialog.lua` — dynamic
  contextual layout: toggles widget/separator `visible` per mode; persists window
  position via `show{wait=false, bounds=...}`.
- **JRiggles/Aseprite-Extension-Template** — packaging skeleton + the "Give full
  trust to this script" install documentation pattern.

## Phases

### Phase 0 — Robustness & honesty (no new UI)
The polish floor, independent of looks:
- Gate features on `app.version` / `app.apiVersion`; guard `app.isUIAvailable` /
  `Dialog() == nil` so the script is `--batch`-safe.
- **Minimize permission prompts.** The sandbox grants are per-script-file and
  per-mode (Execute / Read / Write); our shell-out + read-back + temp-write touches
  all three. Reduce the surface (make the stderr read-back best-effort/silent), and
  add a README **Permissions** section with a screenshot telling users to tick
  "Give full trust to this script" once. (Research `01 §4`.)
- All paths via `app.fs.*`; confirm `app.fs.tempPath` usage; test Win/macOS/Linux.

### Phase 1 — Layout polish (works on 1.2.18+, no canvas)
Make the existing dialog look organized and behave smartly, using only widgets
available without the Canvas:
- `separator{ text="…" }` section headers (Source size / Palette / Mosaic / Output).
- Linked **width/height px ↔ %** with a "Lock Ratio" check (K-Centroid pattern).
- **Reactive visibility** via `dlg:modify{ visible=… }`: show the palette-file
  picker only when Palette = "(custom file…)"; show build-map/pieces paths only when
  their checkbox is on. (Magic Pencil pattern.)
- Persist window position across reopen via `show{ wait=false, bounds=dlg.bounds }`;
  keep persisting settings via `plugin.preferences`.

### Phase 2 — Live before/after preview (Aseprite 1.3+ / apiVersion ≥ 20)
The headline upgrade. Gate on `app.apiVersion >= 20`; on older versions fall back to
the Phase-1 dialog (no preview) gracefully.
- Non-modal dialog (`show{ wait=false }`) with a `dlg:canvas{}`; draw **before** and
  **after** as two halves via `ctx:drawImage(img, srcRect, dstRect)` so Aseprite
  does the scaling.
- **Cache** the reduced result `Image` at native size; `onpaint` only blits.
  Recompute on `onchange` for cheap params, on `slider.onrelease` for the expensive
  palette reduction (the documented substitute for debouncing).
- Theme-match: fill the canvas background with `app.theme.color.window_face`, labels
  in `app.theme.color.text` with a shadow pass for contrast; `ctx.antialias=false`
  for crisp pixels. Keep `onpaint` pure-drawing (avoids the layout-height bug
  #3747).
- Decide preview source: run the binary on a downscaled proxy for snappy preview,
  full-res only on Apply. (Binary call latency is the constraint — measure; consider
  a "Preview" button if live is too slow.)

### Phase 3 — Palette swatch strip + mosaic affordances
- A second `dlg:canvas{}` drawing one `fillRect` per derived/loaded palette color;
  hit-test clicks (`ev.x / width`) to set foreground / inspect a color.
- Surface the parts-list counts (from `-pieces`) and a one-click "open build map".

### Phase 4 — Distribution polish
- Icon, screenshots (preview + permissions), a written README with the install +
  trust flow.
- CI: GitHub Action building the `.aseprite-extension` and publishing to itch.io via
  `butler` (research `01 §5`); bundle the per-OS binary with `make bin` so the
  extension is self-contained.
- Version bump to a real `0.x` release; tag.

## Definition of Done — Plan A

Done when **all** of:

1. **Works and degrades gracefully.** Full Canvas live-preview UI on Aseprite 1.3+
   (apiVersion ≥ 20); on 1.2.18–1.2.x it falls back to a functional, organized
   non-preview dialog. No errors when run headless (`--batch`).
2. **Live preview.** Before/after updates as parameters change (cheap on `onchange`,
   expensive on `onrelease`), theme-matched, crisp (no AA), with cached result image
   — no recompute storms, no #3747 layout glitch.
3. **Polished controls.** Sectioned layout with labeled separators; linked
   width/height + Lock Ratio; reactive show/hide of conditional fields; palette
   swatch strip; window position + preferences persisted.
4. **Honest permissions.** One-time "Full trust" grant documented with a screenshot;
   prompt surface minimized; all file I/O via `app.fs.*`.
5. **Clean install, cross-platform.** Double-click `.aseprite-extension` installs;
   binary bundled (or found on PATH); verified on Windows, macOS, Linux.
6. **Shippable.** README with screenshots + permissions section; itch.io listing; CI
   publishes the packaged extension; tagged release.

**Non-goals for this track:** the palette-derivation algorithm itself (that's
Plan B, in the engine; the plugin only exposes it through the binary once it lands).
No in-Lua image processing — the binary stays the single source of truth.
