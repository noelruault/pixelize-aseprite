# pixelize for Aseprite

Resize a sprite and snap **every pixel to its exact nearest color** in a palette
you choose — NES, Game Boy, PICO-8, lego, perler, cross-stitch, or your own
`.csv` / `.hex` / `.gpl` / `.json` file — directly inside Aseprite. Optionally
emit a **build map** and **parts list** for a physical lego / perler /
cross-stitch mosaic.

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

- **Aseprite 1.2.18+** (extension/plugin support).
- The **`pixelize` binary**, found one of three ways, in order:
  1. a path you set in the dialog (persisted between sessions);
  2. a binary bundled inside the extension at `bin/pixelize` (`bin/pixelize.exe`
     on Windows) — see [Bundling the binary](#bundling-the-binary);
  3. `pixelize` on your system `PATH` (`go install
     github.com/noelruault/pixelize/cmd/pixelize@latest`).

The first time you run it, Aseprite shows a **script-security prompt** because
the extension launches an external program. Grant it access (choose full trust
to stop being asked).

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
| Palette | `-palette NAME` | Built-ins: `gameboy`, `lego`, `lego-grayscale`, `nes`, `pico8`, `tol-bright`, `wong`. |
| Palette file | `-palette PATH` | Used when Palette is set to `(custom file…)`. |
| Resize / Width / Height | `-size WxH` | Off by default; keeps the sprite's size. Width/height link via **Lock aspect ratio**. |
| Resize mode | `-mode` | `nn` (default) · `avg` · `bilinear` · `catmullrom`. |
| Floyd-Steinberg dither | `-dither` | Off snaps each pixel to its nearest color. |
| Build map | `-build-map PATH` | Per-cell placement for a physical mosaic. |
| Parts list | `-pieces PATH` | Per-color piece-count CSV (shopping list). |

## Scope

v1 ports what the engine already does — resize, nearest-palette reduction, and
the build-map / parts-list outputs. It intentionally does **not** add the
features of neighboring Aseprite plugins (k-centroid downscaling, orphan-pixel
denoising). Those, if added, belong in the engine so the CLI and library get
them too.

## License

MIT. See [LICENSE](LICENSE).
