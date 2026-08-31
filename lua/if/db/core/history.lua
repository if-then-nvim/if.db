local config = require "if.db.config"

local M = {}

---@type IfDb.HistoryEntry[]
M.entries = {}

---@return string
function M.get_history_path()
  local data_dir = vim.fn.stdpath "data"
  return data_dir .. "/if.db/history.json"
end

---@return boolean success
local function ensure_data_dir()
  local data_dir = vim.fn.stdpath "data" .. "/if.db"
  if vim.fn.isdirectory(data_dir) == 0 then
    local result = vim.fn.mkdir(data_dir, "p")
    return result == 1
  end
  return true
end

function M.load()
  local cfg = config.get()
  if not cfg.history.persist then
    return
  end

  local path = M.get_history_path()
  if vim.fn.filereadable(path) == 0 then
    M.entries = {}
    return
  end

  local file = io.open(path, "r")
  if not file then
    M.entries = {}
    return
  end

  local content = file:read "*a"
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if ok and type(data) == "table" then
    M.entries = data
  else
    M.entries = {}
  end
end

function M.save()
  local cfg = config.get()
  if not cfg.history.persist then
    return
  end

  if not ensure_data_dir() then
    vim.notify("[if.db] Failed to create data directory", vim.log.levels.ERROR)
    return
  end

  local path = M.get_history_path()
  local file = io.open(path, "w")
  if not file then
    vim.notify("[if.db] Failed to save history", vim.log.levels.ERROR)
    return
  end

  local ok, json = pcall(vim.json.encode, M.entries)
  if ok then
    file:write(json)
  end
  file:close()
end

---@param entry IfDb.HistoryEntry
function M.add(entry)
  local cfg = config.get()

  table.insert(M.entries, 1, entry)

  while #M.entries > cfg.history.max_entries do
    table.remove(M.entries)
  end

  M.save()
end

---@return IfDb.HistoryEntry[]
function M.get_all()
  return M.entries
end

function M.clear()
  M.entries = {}
  M.save()
end

---@param index number 1-based index
function M.delete(index)
  if index >= 1 and index <= #M.entries then
    table.remove(M.entries, index)
    M.save()
  end
end

---@param query string
---@return string verb, string? target
local function parse_query(query)
  local normalized = query:gsub("%s+", " "):upper():sub(1, 200)

  local patterns = {
    { pattern = "^%s*SELECT%s+.-%s+FROM%s+(%S+)", verb = "SEL" },
    { pattern = "^%s*INSERT%s+INTO%s+(%S+)", verb = "INS" },
    { pattern = "^%s*UPDATE%s+(%S+)", verb = "UPD" },
    { pattern = "^%s*DELETE%s+FROM%s+(%S+)", verb = "DEL" },
    { pattern = "^%s*CREATE%s+TABLE%s+(%S+)", verb = "CRT" },
    { pattern = "^%s*DROP%s+TABLE%s+(%S+)", verb = "DRP" },
    { pattern = "^%s*ALTER%s+TABLE%s+(%S+)", verb = "ALT" },
    { pattern = "^%s*TRUNCATE%s+TABLE%s+(%S+)", verb = "TRC" },
  }

  for _, p in ipairs(patterns) do
    local target = normalized:match(p.pattern)
    if target then
      target = target:gsub("[\"'`%[%]]", ""):match "[^.]+$" or target
      return p.verb, target:lower()
    end
  end

  return "SQL", nil
end

---@param entry IfDb.HistoryEntry
---@return string summary, string verb
function M.format_summary(entry)
  local verb, target = parse_query(entry.query)
  local time = os.date("%H:%M", entry.timestamp)

  local summary
  if target then
    summary = time .. " " .. verb .. " " .. target
  else
    local short_query = entry.query:gsub("%s+", " "):sub(1, 15)
    if #entry.query > 15 then
      short_query = short_query .. "…"
    end
    summary = time .. " " .. short_query
  end

  return summary, verb
end

---@param entry IfDb.HistoryEntry
---@return string target
function M.get_query_target(entry)
  local _, target = parse_query(entry.query)
  if target then
    return target
  end
  local short_query = entry.query:gsub("%s+", " "):sub(1, 12)
  if #entry.query > 12 then
    short_query = short_query .. "…"
  end
  return short_query
end

---@param verb string
---@return string
function M.get_verb_icon(verb)
  local icons = require "if.db.ui.icons"
  return icons.verb(verb)
end

---@param duration_ms? number
---@return string
function M.format_duration(duration_ms)
  if not duration_ms then
    return ""
  end

  if duration_ms < 1000 then
    return string.format("%dms", math.floor(duration_ms))
  elseif duration_ms < 60000 then
    return string.format("%.1fs", duration_ms / 1000)
  else
    return string.format("%.1fm", duration_ms / 60000)
  end
end

return M
