-- Bridges Neovim to the system-wide `theme` switcher.
--
-- There is no generated Lua file: Neovim reads ~/.config/theme/current and
-- ~/.config/theme/themes.json directly, so a theme switch is picked up by new
-- instances automatically, and by running ones via:
--
--     nvim --server <sock> --remote-send ':lua require("config.theme").reload()<CR>'
--
-- which is exactly what `theme` does for every live socket.

local M = {}

-- Used when the catalog is missing or names a colorscheme that is not
-- installed, so a broken theme file can never leave you with no colours.
local FALLBACK = "catppuccin-mocha"

local function config_home()
  return os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
end

local function read_file(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local content = fd:read("*a")
  fd:close()
  return content
end

--- Colorscheme name for the currently active system theme.
---@return string
function M.current()
  local dir = config_home() .. "/theme"

  local slug = read_file(dir .. "/current")
  if not slug then
    return FALLBACK
  end
  slug = vim.trim(slug)
  if slug == "" then
    return FALLBACK
  end

  local raw = read_file(dir .. "/themes.json")
  if not raw then
    return FALLBACK
  end

  local ok, catalog = pcall(vim.json.decode, raw)
  if not ok or type(catalog) ~= "table" or type(catalog.themes) ~= "table" then
    return FALLBACK
  end

  local entry = catalog.themes[slug]
  if type(entry) ~= "table" or type(entry.nvim) ~= "string" then
    return FALLBACK
  end

  return entry.nvim
end

--- Apply the active theme, falling back if the colorscheme is not installed.
--- Returns the name that was actually applied.
function M.apply()
  local scheme = M.current()
  if not pcall(vim.cmd.colorscheme, scheme) then
    pcall(vim.cmd.colorscheme, FALLBACK)
    return FALLBACK
  end
  return scheme
end

--- Re-read the catalog and apply. Called remotely by the `theme` script.
function M.reload()
  -- Reuse apply()'s return rather than calling current() again: each call
  -- re-reads two files and re-decodes the catalog.
  local scheme = M.apply()
  vim.notify("theme → " .. scheme, vim.log.levels.INFO, { title = "theme" })
end

return M
