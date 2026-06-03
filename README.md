# pixelize for Aseprite

Resize a sprite and snap **every pixel to its exact nearest color** in a palette
you choose — NES, Game Boy, PICO-8, lego, perler, cross-stitch, or your own
`.csv` / `.hex` / `.gpl` / `.json` file — directly inside Aseprite. Or **derive a
palette from the image itself** (`auto:N`) to turn any sprite into clean N-color
pixel art. Optionally emit a **build map** and **parts list** for a physical
lego / perler / cross-stitch mosaic.

This is a thin front-end for [`pixelize`](https://github.com/noelruault/pixelize),
the command-line engine. It does **not** reimplement the color work in Lua: it
exports the active frame, hands it to the `pixelize` binary, and opens the
result back in Aseprite. The engine stays the single source of truth, so the
extension inherits the engine's exact nearest-color matching, build maps, and
speed.

## How it works

```
Aseprite canvas ──► temp PNG ──► pixelize binary ──► result PNG ──► new tab
                                      │
                                      ├─► build map (optional)
                                      └─► parts list (optional)
```

## Requirements

- **Aseprite 1.3+** (the current stable release; the dialog also runs on
  1.2.18+, the floor for extension support).
- The **`pixelize` binary**, found one of three ways, in order:
  1. a path you set in the dialog (persisted between sessions);
  2. a binary bundled inside the extension at `bin/pixelize` (`bin/pixelize.exe`
     on Windows) — see [Bundling the binary](#bundling-the-binary);
  3. `pixelize` on your system `PATH` (`go install
     github.com/noelruault/pixelize/cmd/pixelize@latest`).

The first time you run it, Aseprite shows a **script-security prompt** because
the extension launches an external program. Grant it access (choose full trust
to stop being asked).

> Deriving a palette (`Palette → auto`) needs a **recent `pixelize`** — one built
> with the `quantize` feature (`-palette auto:N`). A bundled build (below) or a
> fresh `go install …@latest` has it; a stale binary on `PATH` will report an
> unknown palette.

## Install

1. Download or build `pixelize.aseprite-extension` (see below).
2. In Aseprite: **Edit → Preferences → Extensions → Add Extension**, pick the
   file. Or just double-click the `.aseprite-extension` file.
3. Run it from **Sprite → Pixelize…**.

## Build the extension

```sh
make package          # zips package.json + pixelize.lua (+ bin/ if present)
```

### Bundling the binary

To ship a self-contained extension that does not depend on `PATH`, build the
engine into `bin/` first, then package:

```sh
make bin              # builds ../pixelize into ./bin for the host OS
make package          # bundles bin/ into the .aseprite-extension
```

Cross-compile for another target before packaging:

```sh
GOOS=windows GOARCH=amd64 make bin
GOOS=darwin  GOARCH=arm64 make bin
```

`make bin` expects a sibling checkout of `noelruault/pixelize` at `../pixelize`;
override with `make bin ENGINE=/path/to/pixelize`.

## Options

| Dialog field | pixelize flag | Notes |
| --- | --- | --- |
| Palette | `-palette NAME` | Built-ins: `gameboy`, `lego`, `lego-grayscale`, `nes`, `pico8`, `tol-bright`, `wong`; or `(auto …)` / `(custom file…)`. |
| Colors *(auto)* | `-palette auto:N` | Shown when Palette = auto. Derive an N-color palette from the image (2–256). |
| Color space *(auto)* | `-quantize` | `auto` (default, picks by N) · `rgb` · `oklab`. |
| Curve init *(auto)* | `-curve-init` | Space-filling-curve initializer; helps at N ≥ 256. |
| Palette file | `-palette PATH` | Used when Palette is set to `(custom file…)`. |
| Merge similar | `-merge DIST` | Collapse palette colors closer than DIST (8-bit RGB). Works on derived **or** loaded palettes. `0` = off. |
| Resize / Width / Height | `-size WxH` | Off by default; keeps the sprite's size. Width/height link via **Lock aspect ratio**. |
| Resize mode | `-mode` | `nn` (default) · `avg` · `bilinear` · `catmullrom`. |
| Floyd-Steinberg dither | `-dither` | Off snaps each pixel to its nearest color. |
| Build map | `-build-map PATH` | Per-cell placement for a physical mosaic. |
| Parts list | `-pieces PATH` | Per-color piece-count CSV (shopping list). |

## Scope

The extension is a thin front-end: every feature is a flag on the `pixelize`
binary (resize, fixed-palette reduction, **palette derivation** `auto:N`, merge,
build-map / parts-list). It deliberately reimplements nothing in Lua — new
capability is added to the engine, then surfaced here, so the CLI and Go library
get it too.

A live **before/after preview** (Aseprite 1.3 Canvas) and a palette **swatch
strip** are the next planned steps; see [`.plans/00-polish-plan.md`](.plans/00-polish-plan.md).

## License

MIT. See [LICENSE](LICENSE).
