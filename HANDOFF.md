# HANDOFF — picking up the Pixelize extension

Short guide to continue the extension work from a fresh machine. Last updated at
**v0.2.0**.

## Where we are

- ✅ Binary-backed extension: dialog exports the active frame, runs the `pixelize`
  binary, opens the result back.
- ✅ **Phase 0–1** (robustness + layout polish) and **engine parity (v0.2.0)** — the
  dialog now exposes the full engine, including `Palette → auto` (`-palette auto:N`),
  Color space (`-quantize`), Curve init (`-curve-init`), and Merge similar (`-merge`).
- ⬜ **Phase 2** live Canvas before/after preview · **Phase 3** swatch strip · **Phase 4**
  distribution. See [`.plans/00-polish-plan.md`](.plans/00-polish-plan.md).

**The one thing not yet done: it has never been run inside Aseprite.** Everything is
verified by `luac` parse + testing the emitted commands against the engine. The
dialog rendering, the reactive show/hide, the `os.execute` security prompt, and the
`app.open` round-trip are **unconfirmed by a human**. Closing that is step 1 below.

## Pick up in 4 steps

```sh
# 1. Clone this repo and the engine side-by-side (make bin needs ../pixelize).
git clone https://github.com/noelruault/pixelize-aseprite
git clone https://github.com/noelruault/pixelize          # sibling, for the binary

# 2. Build the pixelize binary into the extension (so `auto` works), needs Go 1.26+.
cd pixelize-aseprite
make bin            # builds ../pixelize into ./bin/  (or skip and put `pixelize` on PATH)

# 3. Package and install.
make package       # -> pixelize.aseprite-extension
#   Aseprite: Edit > Preferences > Extensions > Add Extension > pick that file.
#   First run pops a script-security prompt — choose "Give full trust".
```

```
# 4. Test it: open an image as a sprite, then Sprite > Pixelize…
```

### What to verify in Aseprite (the smoke test)

- **Dialog renders** and is laid out sensibly (sectioned by separators).
- **Reactive show/hide** works: the `auto` controls (Colors / Color space / Curve
  init) appear only when Palette = `(auto …)`; the Palette file picker only for
  `(custom file…)`; the Build map / Parts list paths only when their boxes are checked.
- **Fixed palette**: Palette = `nes`, Resize 64×64 → Pixelize → a reduced sprite opens.
- **Derive**: Palette = `(auto …)`, Colors = 16 → derives a 16-color palette.
- **Merge**: set Merge similar = 10 → fewer colors than requested.
- **Mosaic**: set a Build map / Parts list path → files are written.
- **Lock aspect ratio** keeps width/height proportional; window position persists.

Note any breakage — those become the first fixes.

## Next task

1. Apply fixes from the smoke test (if any).
2. **Phase 2 — Canvas live before/after preview** (Aseprite 1.3+). Spec, exemplars,
   and the verified API patterns are in [`.plans/00-polish-plan.md`](.plans/00-polish-plan.md)
   (Phase 2) and [`.plans/02-ui-reverse-engineering.md`](.plans/02-ui-reverse-engineering.md).

## Map of the repo

- `pixelize.lua` — the whole extension (dialog, command builder, run).
- `package.json` — manifest (v0.2.0).
- `Makefile` — `make bin` (build engine into `bin/`), `make package` (zip the extension).
- `.plans/` — Plan A (`00-polish-plan.md`), the extension-quality and UI
  reverse-engineering reference notes, and a README index.
- Engine docs (auto/quantize/merge): `noelruault/pixelize` README + `docs/methodology.md`.
