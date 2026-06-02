-- pixelize.lua — Aseprite front-end for the pixelize engine.
--
-- This extension does not reimplement the resize + nearest-palette
-- reduction in Lua. It exports the active frame to a temporary PNG,
-- hands it to the `pixelize` command-line binary, and opens the result
-- back in Aseprite. The Go binary owns all the heavy lifting (exact
-- nearest-color matching, build maps, parts lists), so there is a single
-- source of truth shared with the CLI and the Go library.
--
-- Running an external program triggers Aseprite's script-security prompt
-- the first time. Grant the script execute access (and full-trust if you
-- want to stop being asked) to let it call the binary.

-- Embedded palette names that ship inside the binary. A file you place in
-- your pixelize palette directory with the same name overrides these.
local EMBEDDED_PALETTES = {
  "gameboy", "lego", "lego-grayscale", "nes", "pico8", "tol-bright", "wong",
}
local CUSTOM_PALETTE_LABEL = "(custom file…)"

local RESIZE_MODES = { "nn", "avg", "bilinear", "catmullrom" }

local function isWindows()
  return app.fs.pathSeparator == "\\"
end

local function exeName()
  return isWindows() and "pixelize.exe" or "pixelize"
end

-- tempDir returns a writable directory for the intermediate PNGs.
local function tempDir()
  -- app.fs.tempPath is available on recent Aseprite; fall back to the
  -- extension directory if it is not.
  local t = app.fs.tempPath
  if t and #t > 0 then return t end
  return app.fs.filePath(app.fs.normalizePath(debug.getinfo(1, "S").source:sub(2)))
end

-- resolveBinary returns the command token used to invoke pixelize:
-- 1) a user-set path in preferences, if it exists on disk;
-- 2) a binary bundled under <extension>/bin, if present;
-- 3) the bare name "pixelize", resolved against PATH.
local function resolveBinary(plugin)
  local pref = plugin.preferences.binPath
  if pref and #pref > 0 and app.fs.isFile(pref) then
    return pref, true
  end

  local bundled = app.fs.joinPath(plugin.path, "bin", exeName())
  if app.fs.isFile(bundled) then
    return bundled, true
  end

  return exeName(), false
end

-- quote wraps a value in double quotes for the shell. The paths this
-- extension produces (temp files, user-picked outputs) do not contain
-- embedded double quotes, so plain wrapping is enough.
local function quote(s)
  return '"' .. tostring(s) .. '"'
end

-- exportActiveFrame renders the composited active frame to a PNG so the
-- binary sees exactly what the canvas shows, regardless of layers.
local function exportActiveFrame(sprite, path)
  local img = Image(sprite.spec)
  img:drawSprite(sprite, app.activeFrame)
  img:saveAs(path)
end

-- buildCommand assembles the pixelize invocation from the dialog data.
local function buildCommand(bin, inPath, outPath, data, errPath)
  local parts = { bin, quote(inPath) }

  if data.resize then
    parts[#parts + 1] = "-size"
    parts[#parts + 1] = quote(tostring(data.width) .. "x" .. tostring(data.height))
    parts[#parts + 1] = "-mode"
    parts[#parts + 1] = data.mode
  end

  local palette = data.palette
  if palette == CUSTOM_PALETTE_LABEL then
    palette = data.paletteFile
  end
  parts[#parts + 1] = "-palette"
  parts[#parts + 1] = quote(palette)

  if data.dither then
    parts[#parts + 1] = "-dither"
  end

  if data.buildMap and data.buildMapPath and #data.buildMapPath > 0 then
    parts[#parts + 1] = "-build-map"
    parts[#parts + 1] = quote(data.buildMapPath)
  end

  if data.pieces and data.piecesPath and #data.piecesPath > 0 then
    parts[#parts + 1] = "-pieces"
    parts[#parts + 1] = quote(data.piecesPath)
  end

  parts[#parts + 1] = "-o"
  parts[#parts + 1] = quote(outPath)

  -- Capture stderr so a failed run can show the binary's own message.
  parts[#parts + 1] = "2>"
  parts[#parts + 1] = quote(errPath)

  return table.concat(parts, " ")
end

local function readFile(path)
  local f = io.open(path, "r")
  if not f then return "" end
  local s = f:read("*a")
  f:close()
  return s or ""
end

local function run(plugin, data)
  local sprite = app.activeSprite
  if not sprite then
    app.alert("Pixelize: no active sprite.")
    return
  end

  if data.palette == CUSTOM_PALETTE_LABEL
      and (not data.paletteFile or #data.paletteFile == 0) then
    app.alert("Pixelize: choose a palette file, or pick a built-in palette.")
    return
  end

  local bin = resolveBinary(plugin)
  local dir = tempDir()
  local stamp = tostring(os.time())
  local inPath  = app.fs.joinPath(dir, "pixelize_in_"  .. stamp .. ".png")
  local outPath = app.fs.joinPath(dir, "pixelize_out_" .. stamp .. ".png")
  local errPath = app.fs.joinPath(dir, "pixelize_err_" .. stamp .. ".txt")

  exportActiveFrame(sprite, inPath)

  local cmd = buildCommand(bin, inPath, outPath, data, errPath)
  local ok, kind, code = os.execute(cmd)

  -- Lua 5.4 os.execute returns (true|nil, "exit"|"signal", code).
  local succeeded = (ok == true) or (ok == 0)
  if not succeeded or (code ~= nil and code ~= 0) or not app.fs.isFile(outPath) then
    local msg = readFile(errPath)
    if #msg == 0 then
      msg = "pixelize did not produce an output (exit " .. tostring(code) .. ").\n\n"
        .. "Checked binary: " .. bin .. "\n"
        .. "If it is not on your PATH, set its location in the dialog."
    end
    app.alert{ title = "Pixelize failed", text = msg }
    return
  end

  if data.openResult then
    app.open(outPath)
  end

  -- Best-effort cleanup of the intermediate files we created.
  os.remove(inPath)
  os.remove(errPath)
  -- outPath is left for Aseprite to keep the opened sprite backed by a file;
  -- if the user did not open it, remove it too.
  if not data.openResult then
    os.remove(outPath)
  end
end

local function showDialog(plugin)
  if not app.isUIAvailable then
    return
  end
  local prefs = plugin.preferences
  local sprite = app.activeSprite

  -- Original dimensions, captured once, so the aspect lock and defaults are
  -- relative to the sprite the user is looking at.
  local origW = (sprite and sprite.width) or 64
  local origH = (sprite and sprite.height) or 64

  local paletteOptions = {}
  for _, p in ipairs(EMBEDDED_PALETTES) do paletteOptions[#paletteOptions + 1] = p end
  paletteOptions[#paletteOptions + 1] = CUSTOM_PALETTE_LABEL

  local dlg = Dialog{ title = "Pixelize" }

  -- sync reflects the current control state into the dialog: it hides fields
  -- that don't apply and greys out the resize controls when resizing is off.
  -- One function, driven from every relevant handler, instead of scattering
  -- visibility logic across callbacks.
  local function sync()
    local d = dlg.data
    dlg:modify{ id = "paletteFile",  visible = d.palette == CUSTOM_PALETTE_LABEL }
    dlg:modify{ id = "width",        enabled = d.resize }
    dlg:modify{ id = "height",       enabled = d.resize }
    dlg:modify{ id = "mode",         enabled = d.resize }
    dlg:modify{ id = "lockRatio",    enabled = d.resize }
    dlg:modify{ id = "buildMapPath", visible = d.buildMap == true }
    dlg:modify{ id = "piecesPath",   visible = d.pieces == true }
  end

  -- Linked resize: px fields are the single source of truth (no percent
  -- fields, no silent clamping). When the ratio is locked, editing one
  -- dimension derives the other from the original aspect ratio.
  local function onWidth()
    if dlg.data.lockRatio and origW > 0 then
      dlg:modify{ id = "height", text = tostring(math.max(1, math.floor(dlg.data.width * origH / origW + 0.5))) }
    end
  end
  local function onHeight()
    if dlg.data.lockRatio and origH > 0 then
      dlg:modify{ id = "width", text = tostring(math.max(1, math.floor(dlg.data.height * origW / origH + 0.5))) }
    end
  end

  dlg:combobox{
    id = "palette",
    label = "Palette",
    option = prefs.palette or "nes",
    options = paletteOptions,
    onchange = sync,
  }
  dlg:file{
    id = "paletteFile",
    label = "Palette file",
    open = true,
    filename = prefs.paletteFile or "",
    filetypes = { "csv", "hex", "gpl", "json" },
  }

  dlg:separator{ text = "Resize" }
  dlg:check{
    id = "resize",
    label = "Resize before reducing",
    selected = prefs.resize == true,
    onclick = sync,
  }
  dlg:number{
    id = "width",
    label = "Width",
    text = tostring(prefs.width or origW),
    decimals = 0,
    onchange = onWidth,
  }
  dlg:number{
    id = "height",
    label = "Height",
    text = tostring(prefs.height or origH),
    decimals = 0,
    onchange = onHeight,
  }
  dlg:check{
    id = "lockRatio",
    label = "Lock aspect ratio",
    selected = prefs.lockRatio ~= false,
  }
  dlg:combobox{
    id = "mode",
    label = "Resize mode",
    option = prefs.mode or "nn",
    options = RESIZE_MODES,
  }

  dlg:separator{ text = "Color" }
  dlg:check{
    id = "dither",
    label = "Floyd-Steinberg dither",
    selected = prefs.dither == true,
  }

  dlg:separator{ text = "Physical mosaic (optional)" }
  dlg:check{
    id = "buildMap",
    label = "Write build map",
    selected = prefs.buildMap == true,
    onclick = sync,
  }
  dlg:file{
    id = "buildMapPath",
    label = "Build map",
    save = true,
    filename = prefs.buildMapPath or "",
    filetypes = { "txt" },
  }
  dlg:check{
    id = "pieces",
    label = "Write parts list",
    selected = prefs.pieces == true,
    onclick = sync,
  }
  dlg:file{
    id = "piecesPath",
    label = "Parts list",
    save = true,
    filename = prefs.piecesPath or "",
    filetypes = { "csv" },
  }

  dlg:separator{}
  dlg:check{
    id = "openResult",
    label = "Open result in Aseprite",
    selected = prefs.openResult ~= false,
  }

  dlg:button{ id = "ok", text = "Pixelize", focus = true }
  dlg:button{ id = "cancel", text = "Cancel" }

  sync() -- set initial visibility before the dialog is shown

  -- Restore the last window position if we saved one.
  if prefs.boundsX and prefs.boundsY then
    dlg:show{ bounds = Rectangle(prefs.boundsX, prefs.boundsY,
                                 dlg.bounds.width, dlg.bounds.height) }
  else
    dlg:show()
  end

  prefs.boundsX = dlg.bounds.x
  prefs.boundsY = dlg.bounds.y

  local data = dlg.data
  if not data.ok then return end
  prefs.lockRatio = data.lockRatio

  -- Persist the choices for next time.
  prefs.palette      = data.palette
  prefs.paletteFile  = data.paletteFile
  prefs.resize       = data.resize
  prefs.width        = data.width
  prefs.height       = data.height
  prefs.mode         = data.mode
  prefs.dither       = data.dither
  prefs.buildMap     = data.buildMap
  prefs.buildMapPath = data.buildMapPath
  prefs.pieces       = data.pieces
  prefs.piecesPath   = data.piecesPath
  prefs.openResult   = data.openResult

  run(plugin, data)
end

function init(plugin)
  plugin:newCommand{
    id = "pixelize",
    title = "Pixelize…",
    group = "sprite_color",
    onenabled = function() return app.activeSprite ~= nil end,
    onclick = function() showDialog(plugin) end,
  }
end

function exit(plugin) -- luacheck: ignore
  -- Nothing to tear down; preferences persist automatically.
end
