local M = {}

-- How far each row background sits from the editor background, as a
-- fraction of the distance to white on a dark theme or to black on a
-- light one. Small numbers: the stripe is meant to group rows, not to
-- draw a second background.
local STRIPE_ODD = 0.02
local STRIPE_EVEN = 0.07

---@param hex string
---@return number relative luminance, 0..1
local function luminance(hex)
  hex = hex:gsub("^#", "")
  local r = tonumber(hex:sub(1, 2), 16) / 255
  local g = tonumber(hex:sub(3, 4), 16) / 255
  local b = tonumber(hex:sub(5, 6), 16) / 255
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

---Move `hex` a fraction `t` of the way toward `target`, one channel at a
---time. Every channel moves by the same fraction, so the result keeps the
---hue it started with; the only targets used are white and black, which
---carry no hue of their own to bleed in.
---@param hex string
---@param target string
---@param t number 0..1
---@return string
local function blend(hex, target, t)
  hex = hex:gsub("^#", "")
  target = target:gsub("^#", "")
  local out = {}
  for i = 0, 2 do
    local a = tonumber(hex:sub(i * 2 + 1, i * 2 + 2), 16)
    local b = tonumber(target:sub(i * 2 + 1, i * 2 + 2), 16)
    out[i + 1] = math.floor(a + (b - a) * t + 0.5)
  end
  return string.format("#%02x%02x%02x", out[1], out[2], out[3])
end

---The colour the row stripes are derived from. Normal is the editor's own
---background and the right answer whenever it has one; a transparent
---theme leaves it unset, and CursorLine is then the closest thing to a
---surface colour the colorscheme offers.
---@return string|nil
local function base_bg()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
  if normal.bg then
    return string.format("#%06x", normal.bg)
  end
  local cursorline = vim.api.nvim_get_hl(0, { name = "CursorLine" })
  if cursorline.bg then
    return string.format("#%06x", cursorline.bg)
  end
  return nil
end

local function apply()
  local bg = base_bg()

  local row_odd_bg, row_even_bg
  if bg then
    -- Away from the background's own end of the scale, so there is always
    -- headroom: a near-white theme darkens, a near-black one lightens, and
    -- neither clips into a stripe indistinguishable from the background.
    local target = luminance(bg) < 0.5 and "#ffffff" or "#000000"
    row_odd_bg = blend(bg, target, STRIPE_ODD)
    row_even_bg = blend(bg, target, STRIPE_EVEN)
  else
    row_odd_bg = "#1e2230"
    row_even_bg = "#282c3f"
  end

  vim.api.nvim_set_hl(0, "IfDbRowOdd", { bg = row_odd_bg })
  vim.api.nvim_set_hl(0, "IfDbRowEven", { bg = row_even_bg })

  local func_hl = vim.api.nvim_get_hl(0, { name = "Function" })
  local header_bg = func_hl.fg and string.format("#%06x", func_hl.fg) or "#61afef"
  vim.api.nvim_set_hl(0, "IfDbHeader", { bg = header_bg, fg = "#000000", bold = true })

  local highlights = {
    IfDbFloat = { link = "NormalFloat" },
    IfDbBorder = { link = "WinSeparator" },
    IfDbTitle = { link = "Title" },

    IfDbSeparator = { link = "Comment" },
    IfDbCellActive = { link = "CursorLine" },

    IfDbNull = { link = "Comment" },
    IfDbNumber = { link = "Number" },
    IfDbString = { link = "Normal" },
    IfDbBoolean = { link = "Boolean" },
    IfDbDateTime = { link = "Special" },
    IfDbUuid = { link = "Constant" },
    IfDbJson = { link = "Function" },

    IfDbTable = { link = "Type" },
    IfDbKey = { link = "Keyword" },
    IfDbPK = { link = "DiagnosticError", bold = true },
    IfDbFK = { link = "Function", bold = true },

    IfDbIconDb = { link = "Number" },
    IfDbIconPostgres = { fg = "#4169E1", bold = true },
    IfDbIconMysql = { fg = "#4479A1", bold = true },
    IfDbIconSqlite = { fg = "#003B57", bold = true },
    IfDbIconMariadb = { fg = "#003545", bold = true },
    IfDbIconRedis = { fg = "#FF4438", bold = true },
    IfDbIconMongodb = { fg = "#47A248", bold = true },

    IfDbSidebarIconConnection = { link = "Number" },
    IfDbSidebarIconActive = { link = "String" },
    IfDbSidebarIconNewQuery = { link = "Function" },
    IfDbSidebarIconBuffers = { link = "Function" },
    IfDbSidebarIconSaved = { link = "Keyword" },
    IfDbSidebarIconSchemas = { link = "Special" },
    IfDbSidebarIconSchema = { link = "Type" },
    IfDbSidebarIconTable = { link = "Type" },
    IfDbSidebarIconColumn = { link = "Function" },
    IfDbSidebarIconPK = { link = "ErrorMsg" },
    IfDbSidebarText = { link = "Normal" },
    IfDbSidebarTextActive = { link = "String", bold = true },
    IfDbSidebarType = { link = "Comment" },

    IfDbHistoryHeader = { link = "Title", bold = true },
    IfDbHistoryRowOdd = { bg = row_odd_bg },
    IfDbHistoryRowEven = { bg = row_even_bg },
    IfDbHistoryTime = { link = "Comment" },
    IfDbHistoryVerb = { link = "@keyword.sql" },
    IfDbHistoryTarget = { link = "@type.sql" },
    IfDbHistoryColumn = { link = "@variable.member.sql" },
    IfDbHistoryCount = { link = "@number.sql" },
    IfDbHistoryDuration = { link = "Number" },
    IfDbHistoryConnName = { link = "Normal" },
    IfDbHistorySelect = { link = "Function" },
    IfDbHistoryInsert = { link = "String" },
    IfDbHistoryUpdate = { link = "Type" },
    IfDbHistoryDelete = { link = "ErrorMsg" },
    IfDbHistoryCreate = { link = "String" },
    IfDbHistoryDrop = { link = "ErrorMsg" },
    IfDbHistoryAlter = { link = "Special" },
    IfDbHistoryTruncate = { link = "WarningMsg" },
    IfDbHistoryHintWhere = { link = "@keyword.sql" },
    IfDbHistoryHintJoin = { link = "@keyword.sql" },
    IfDbHistoryHintOrder = { link = "@keyword.sql" },
    IfDbHistoryHintGroup = { link = "@keyword.sql" },
    IfDbHistoryHintLimit = { link = "@keyword.sql" },
  }

  for name, opts in pairs(highlights) do
    local existing = vim.api.nvim_get_hl(0, { name = name })
    if vim.tbl_isempty(existing) then
      vim.api.nvim_set_hl(0, name, opts)
    end
  end

  local cfg = require("if.db.config").get()
  if cfg.highlights then
    for name, opts in pairs(cfg.highlights) do
      vim.api.nvim_set_hl(0, name, opts)
    end
  end
end

function M.setup()
  apply()

  -- :colorscheme runs `highlight clear`, which takes every IfDb group with
  -- it, linked ones included. Without this the panes lose their colours
  -- the first time the theme changes and do not get them back until the
  -- plugin is set up again.
  local group = vim.api.nvim_create_augroup("IfDbHighlights", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    desc = "Reapply if.db highlights",
    callback = apply,
  })
end

return M
