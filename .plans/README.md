# .plans

Planning and design artifacts for the Pixelize Aseprite extension. Documentation,
not code — nothing here is run by the extension.

- [`00-polish-plan.md`](00-polish-plan.md) — Plan A: phased plan to take the
  binary-backed scaffold to a polished, good-looking extension (live preview,
  swatch strip, theming), with its Definition of Done.
- [`01-extension-quality.md`](01-extension-quality.md) — verified reference: how the
  best Aseprite extensions are built (manifest, plugin lifecycle, the script-security
  sandbox read from source, packaging, polish checklist).
- [`02-ui-reverse-engineering.md`](02-ui-reverse-engineering.md) — the ADOPT / MAYBE /
  DISCARD UI catalogue, reverse-engineered from the most polished public extensions.

These were reorganized out of the research repo: the Aseprite extension is a build,
so its planning lives here with the code, not in `noelruault/research`.

The companion engine work (Plan B — the `quantize` palette-derivation module this
extension exposes via `-palette auto:N`) is planned in the pixelize repo at
`pixelize/.plans/quantize/`, with its research record in
[`noelruault/research/quantization/`](https://github.com/noelruault/research/tree/main/quantization).
