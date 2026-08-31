local history = require "if.db.core.history"
local config = require "if.db.config"
local connection = require "if.db.core.connection"
local icons = require "if.db.ui.icons"

local M = {}

---@return string|nil
local function get_current_connection_name()
  local ok, workbench = pcall(require, "if.db.ui.workbench")
  if ok and workbench and workbench.get_active_connection_context then
    local conn_name = workbench.get_active_connection_context()
    if conn_name then
      return conn_name
    end
  end
  return connection.get_active_name()
end

---@type number|nil
M.buf = nil

---@type number|nil
M.win = nil

---@type table[] entry_line_map: {{start=N, finish=N}, ...} (1-indexed line numbers)
M.entry_line_map = {}

---@return number buf
function M.get_or_create_buf()
  if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
    return M.buf
  end

  M.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("filetype", "ifdb_history", { buf = M.buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = M.buf })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = M.buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = M.buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = M.buf })
  vim.api.nvim_buf_set_name(M.buf, "[if.db-history]")

  return M.buf
end

---@param entries IfDb.HistoryEntry[]
---@param win_width number
---@param cfg table
---@return string[] lines, table[] highlights, table[] entry_line_map

---@param query string
---@return { text: string, hl: string }[]
local function query_hints(query)
  local flat = " " .. query:gsub("%s+", " ") .. " "
  local upper = flat:upper()
  local parts = {}

  if upper:match "%sWHERE%s" then
    parts[#parts + 1] = { text = "?", hl = "IfDbHistoryHintWhere" }
  end

  if upper:match "%sJOIN%s" then
    local target = flat:match "%s[Jj][Oo][Ii][Nn]%s+([%w_]+)"
    parts[#parts + 1] = { text = "⋈", hl = "IfDbHistoryHintJoin" }
    if target then
      parts[#parts + 1] = { text = target, hl = "IfDbHistoryTarget" }
    end
  end

  if upper:match "%sORDER%s+BY%s" then
    local desc = upper:match "%sORDER%s+BY%s+[%w_.]+%s+DESC" ~= nil
    parts[#parts + 1] = { text = desc and "↓" or "↑", hl = "IfDbHistoryHintOrder" }
  end

  if upper:match "%sGROUP%s+BY%s" then
    parts[#parts + 1] = { text = "⊞", hl = "IfDbHistoryHintGroup" }
  end

  local limit = upper:match "%sLIMIT%s+(%d+)"
  if limit then
    parts[#parts + 1] = { text = "⊤" .. limit, hl = "IfDbHistoryHintLimit" }
  end

  return parts
end

---@param s string
---@param max integer
---@return string
local function truncate(s, max)
  if max <= 0 then
    return ""
  end
  if vim.fn.strdisplaywidth(s) <= max then
    return s
  end
  local out, len = "", 0
  for i = 0, vim.fn.strchars(s) - 1 do
    local char = vim.fn.strcharpart(s, i, 1)
    local char_width = vim.fn.strdisplaywidth(char)
    if len + char_width + 1 > max then
      break
    end
    out = out .. char
    len = len + char_width
  end
  return out .. "…"
end

---@param entries IfDb.HistoryEntry[]
---@param win_width integer
---@return string[] lines, table[] highlights, table[] entry_line_map
local function render_compact(entries, win_width)
  local r_lines = {}
  local r_highlights = {}
  local r_line_map = {}

  for line_nr, entry in ipairs(entries) do
    local line_idx = line_nr - 1
    local segments = {}

    segments[#segments + 1] = { text = os.date("%H:%M", entry.timestamp), hl = "IfDbHistoryTime" }

    local _, verb = history.format_summary(entry)
    segments[#segments + 1] = { text = "  ", hl = nil }
    segments[#segments + 1] = { text = verb, hl = "IfDbHistoryVerb" }
    segments[#segments + 1] = { text = " ", hl = nil }
    segments[#segments + 1] = { text = history.get_query_target(entry), hl = "IfDbHistoryTarget" }

    for _, hint in ipairs(query_hints(entry.query)) do
      segments[#segments + 1] = { text = " ", hl = nil }
      segments[#segments + 1] = hint
    end

    local right = {}
    local duration = history.format_duration(entry.duration_ms)
    if duration ~= "" then
      right[#right + 1] = { text = duration, hl = "IfDbHistoryDuration" }
    end
    local right_width = 0
    for _, seg in ipairs(right) do
      right_width = right_width + vim.fn.strdisplaywidth(seg.text)
    end

    local body_max = win_width - right_width - 2
    local line = ""
    for _, seg in ipairs(segments) do
      local room = body_max - vim.fn.strdisplaywidth(line)
      local text = truncate(seg.text, room)
      if text ~= "" then
        local start_col = #line
        line = line .. text
        if seg.hl then
          r_highlights[#r_highlights + 1] = { line = line_idx, hl = seg.hl, col_start = start_col, col_end = #line }
        end
      end
    end

    if #right > 0 then
      local pad = win_width - vim.fn.strdisplaywidth(line) - right_width - 1
      line = line .. string.rep(" ", math.max(1, pad))
      for _, seg in ipairs(right) do
        local start_col = #line
        line = line .. seg.text
        if seg.hl then
          r_highlights[#r_highlights + 1] = { line = line_idx, hl = seg.hl, col_start = start_col, col_end = #line }
        end
      end
    end

    r_lines[#r_lines + 1] = line

    local row_hl = (line_nr % 2 == 1) and "IfDbHistoryRowOdd" or "IfDbHistoryRowEven"
    table.insert(r_highlights, 1, { line = line_idx, hl = row_hl, col_start = 0, col_end = -1 })

    r_line_map[line_nr] = { start = line_nr, finish = line_nr }
  end

  return r_lines, r_highlights, r_line_map
end

function M.render()
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    return
  end

  local cfg = config.get()
  local all_entries = history.get_all()
  local entries = {}

  if cfg.history.filter_by_connection then
    local current_conn = get_current_connection_name()
    if current_conn then
      for _, entry in ipairs(all_entries) do
        if entry.conn_name == current_conn then
          table.insert(entries, entry)
        end
      end
    end
  else
    entries = all_entries
  end

  local lines = {}
  local highlights = {}

  local winbar_text = "%#IfDbHistoryHeader#" .. icons.history .. " " .. "History%*"
  if cfg.history.filter_by_connection then
    local current_conn = get_current_connection_name()
    if current_conn then
      local conn_icon = icons.db_default .. " "
      winbar_text = "%#IfDbHistoryHeader#"
        .. icons.history
        .. " "
        .. "History %#NonText#[%#IfDbSidebarIconConnection#"
        .. conn_icon
        .. "%#Normal#"
        .. current_conn
        .. "%#NonText#]%*"
    end
  end
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_set_option_value("winbar", winbar_text, { win = M.win })
  end

  local win_width = 30
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    win_width = vim.api.nvim_win_get_width(M.win)
  end

  if #entries == 0 then
    local empty_msg = "  No history yet"
    if cfg.history.filter_by_connection and not get_current_connection_name() then
      empty_msg = "  Connect to DB first"
    end
    table.insert(lines, empty_msg)
    table.insert(highlights, { line = 0, hl = "Comment", col_start = 0, col_end = -1 })
  else
    local render_lines, render_highlights, line_map = render_compact(entries, win_width)

    M.entry_line_map = line_map
    for _, l in ipairs(render_lines) do
      table.insert(lines, l)
    end
    for _, h in ipairs(render_highlights) do
      table.insert(highlights, h)
    end
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = M.buf })
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = M.buf })

  local ns = vim.api.nvim_create_namespace "ifdb_history"
  vim.api.nvim_buf_clear_namespace(M.buf, ns, 0, -1)
  for _, hl in ipairs(highlights) do
    pcall(vim.api.nvim_buf_add_highlight, M.buf, ns, hl.hl, hl.line, hl.col_start, hl.col_end)
  end
end

---@return IfDb.HistoryEntry[]
local function get_filtered_entries()
  local cfg = config.get()
  local all_entries = history.get_all()

  if cfg.history.filter_by_connection then
    local current_conn = get_current_connection_name()
    if current_conn then
      local filtered = {}
      for _, entry in ipairs(all_entries) do
        if entry.conn_name == current_conn then
          table.insert(filtered, entry)
        end
      end
      return filtered
    end
    return {}
  end

  return all_entries
end

---@return IfDb.HistoryEntry|nil, number|nil
function M.get_entry_at_cursor()
  if not M.win or not vim.api.nvim_win_is_valid(M.win) then
    return nil, nil
  end

  local cursor = vim.api.nvim_win_get_cursor(M.win)
  local line = cursor[1] -- 1-indexed

  local entries = get_filtered_entries()

  local entry_idx = nil
  if #M.entry_line_map > 0 then
    for i, range in ipairs(M.entry_line_map) do
      if line >= range.start and line <= range.finish then
        entry_idx = i
        break
      end
    end
  else
    entry_idx = line
  end

  if entry_idx and entry_idx >= 1 and entry_idx <= #entries then
    return entries[entry_idx], entry_idx
  end

  return nil, nil
end

---@param buf number
function M.setup_keymaps(buf)
  local opts = { buffer = buf, noremap = true, silent = true }
  local keymaps = config.get().keymaps.history

  vim.keymap.set("n", keymaps.select, function()
    M.on_select()
  end, opts)

  vim.keymap.set("n", keymaps.execute, function()
    M.execute_entry()
  end, opts)

  vim.keymap.set("n", keymaps.copy, function()
    local entry = M.get_entry_at_cursor()
    if entry then
      vim.fn.setreg("+", entry.query)
      vim.fn.setreg('"', entry.query)
      vim.notify("[if.db] Query copied", vim.log.levels.INFO)
    end
  end, opts)

  vim.keymap.set("n", keymaps.delete, function()
    local entry, idx = M.get_entry_at_cursor()
    if entry and idx then
      vim.ui.select({ "Yes", "No" }, {
        prompt = "Delete this history entry?",
      }, function(choice)
        if choice == "Yes" then
          history.delete(idx)
          M.render()
        end
      end)
    end
  end, opts)

  vim.keymap.set("n", keymaps.clear, function()
    vim.ui.select({ "Yes", "No" }, {
      prompt = "Clear all history?",
    }, function(choice)
      if choice == "Yes" then
        history.clear()
        M.render()
        vim.notify("[if.db] History cleared", vim.log.levels.INFO)
      end
    end)
  end, opts)

  vim.keymap.set("n", config.get().keymaps.close, function()
    local workbench = require "if.db.ui.workbench"
    workbench.close()
  end, opts)

  vim.keymap.set("n", keymaps.to_sidebar, function()
    local workbench = require "if.db.ui.workbench"
    if workbench.sidebar_win and vim.api.nvim_win_is_valid(workbench.sidebar_win) then
      vim.api.nvim_set_current_win(workbench.sidebar_win)
    end
  end, opts)

  vim.keymap.set("n", keymaps.to_result, function()
    local workbench = require "if.db.ui.workbench"
    if workbench.result_win and vim.api.nvim_win_is_valid(workbench.result_win) then
      vim.api.nvim_set_current_win(workbench.result_win)
    end
  end, opts)

  vim.keymap.set("n", "?", function()
    require("if.db.ui.help").show_history()
  end, opts)
end

function M.on_select()
  local entry = M.get_entry_at_cursor()
  if not entry then
    return
  end

  local cfg = config.get()
  if cfg.history.on_select == "execute" then
    M.execute_entry()
  else
    M.load_entry()
  end
end

function M.load_entry()
  local entry = M.get_entry_at_cursor()
  if not entry then
    return
  end

  local workbench = require "if.db.ui.workbench"
  workbench.open_editor_with_query(entry.query)
end

function M.execute_entry()
  local entry = M.get_entry_at_cursor()
  if not entry then
    return
  end

  local workbench = require "if.db.ui.workbench"
  local _, verb = history.format_summary(entry)

  local function do_execute()
    workbench.open_editor_with_query(entry.query)
    vim.schedule(function()
      workbench.execute_query()
    end)
  end

  if verb == "SEL" then
    do_execute()
  else
    local verb_names = {
      INS = "INSERT",
      UPD = "UPDATE",
      DEL = "DELETE",
      CRT = "CREATE",
      DRP = "DROP",
      ALT = "ALTER",
      TRC = "TRUNCATE",
    }
    local verb_name = verb_names[verb] or verb
    vim.ui.select({ "Execute", "Cancel" }, {
      prompt = "Execute " .. verb_name .. " query?",
    }, function(choice)
      if choice == "Execute" then
        do_execute()
      end
    end)
  end
end

---@param win number
function M.setup(win)
  M.win = win
  local buf = M.get_or_create_buf()
  vim.api.nvim_win_set_buf(win, buf)

  vim.api.nvim_set_option_value("number", false, { win = win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = win })
  vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
  vim.api.nvim_set_option_value("foldcolumn", "0", { win = win })
  vim.api.nvim_set_option_value("cursorline", true, { win = win })
  vim.api.nvim_set_option_value("wrap", false, { win = win })
  vim.api.nvim_set_option_value("winfixwidth", true, { win = win })

  M.setup_keymaps(buf)

  history.load()
  M.render()
end

function M.cleanup()
  if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
    pcall(vim.api.nvim_buf_delete, M.buf, { force = true })
  end
  M.buf = nil
  M.win = nil
  M.entry_line_map = {}
end

return M
