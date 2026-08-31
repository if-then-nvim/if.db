local M = {}

---@param hex string|nil
---@param amount number (negative = darker, positive = lighter)
---@param blue_tint? number (add blue tint, default 0)
---@return string|nil
local function adjust_color(hex, amount, blue_tint)
  if not hex or hex == "" then
    return nil
  end
  blue_tint = blue_tint or 0
  hex = hex:gsub("^#", "")
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  local b = tonumber(hex:sub(5, 6), 16)

  r = math.max(0, math.min(255, r + amount))
  g = math.max(0, math.min(255, g + amount))
  b = math.max(0, math.min(255, b + amount + blue_tint))

  return string.format("#%02x%02x%02x", r, g, b)
end

---@return string|nil
local function get_normal_bg()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
  if normal.bg then
    return string.format("#%06x", normal.bg)
  end
  return nil
end

function M.setup()
  local normal_bg = get_normal_bg()

  local row_odd_bg, row_even_bg
  if normal_bg then
    row_odd_bg = adjust_color(normal_bg, -10, 15) -- darker + blue tint
    row_even_bg = adjust_color(normal_bg, 5, 25) -- lighter + more blue tint
  else
    local cursorline = vim.api.nvim_get_hl(0, { name = "CursorLine" })
    if cursorline.bg then
      row_odd_bg = string.format("#%06x", cursorline.bg)
      row_even_bg = adjust_color(row_odd_bg, 15)
    else
      row_odd_bg = "#1e2230"
      row_even_bg = "#282c3f"
    end
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
    IfDbHistoryVerb = { link = "Keyword" },
    IfDbHistoryTarget = { link = "Type" },
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
    IfDbHistoryHintWhere = { link = "WarningMsg" },
    IfDbHistoryHintJoin = { link = "Special" },
    IfDbHistoryHintOrder = { link = "Keyword" },
    IfDbHistoryHintGroup = { link = "Type" },
    IfDbHistoryHintLimit = { link = "Number" },
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

return M
