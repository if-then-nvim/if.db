local connection = require "if.db.core.connection"
local config = require "if.db.config"

local result = require "if.db.ui.result"
local keymaps = require "if.db.ui.keymaps"
local query = require "if.db.ui.query"
local winbar = require "if.db.ui.winbar"

local function get_sidebar()
  return require "if.db.ui.sidebar"
end

local function get_history_ui()
  return require "if.db.ui.history"
end

local MIN_LEFT_WIDTH = 36
local MIN_RIGHT_WIDTH = 40
local MIN_PANE_HEIGHT = 3

---@return { left: integer, top: integer }
local function geometry()
  local cfg = config.get().layout
  local total_width = vim.o.columns
  local total_height = vim.o.lines - 4

  local left = math.max(MIN_LEFT_WIDTH, math.floor(total_width * cfg.left_width))
  left = math.min(left, math.max(MIN_LEFT_WIDTH, total_width - MIN_RIGHT_WIDTH))
  left = math.min(left, math.floor(total_width / 2))

  local top = math.max(MIN_PANE_HEIGHT, math.floor(total_height * cfg.top_ratio))
  top = math.min(top, total_height - MIN_PANE_HEIGHT)

  return { left = left, top = top }
end

local M = {}

---@type number|nil
M.tab_nr = nil

---@type number|nil
M.sidebar_buf = nil

---@type number|nil
M.sidebar_win = nil

---@type number|nil
M.editor_win = nil

---@type number|nil
M.result_buf = nil

---@type number|nil
M.result_win = nil

---@type number|nil
M.history_buf = nil

---@type number|nil
M.history_win = nil

---@type number|nil
M.editor_buf = nil

result.setup(M)
winbar.setup(M, result)
keymaps.setup(M)
query.setup(M)

setmetatable(M, {
  __index = function(_, k)
    if k == "query_tabs" then
      return query.query_tabs
    end
    if k == "active_tab" then
      return query.active_tab
    end
    if k == "last_result" then
      return result.last_result
    end
    if k == "last_query" then
      return result.last_query
    end
    if k == "last_duration" then
      return result.last_duration
    end
    if k == "last_conn_name" then
      return result.last_conn_name
    end
    if k == "last_timestamp" then
      return result.last_timestamp
    end
    if k == "last_result_width" then
      return result.last_result_width
    end
    if k == "history" then
      return query.history
    end
    if k == "history_index" then
      return query.history_index
    end
  end,
  __newindex = function(t, k, v)
    if k == "active_tab" then
      query.active_tab = v
      return
    end
    if k == "last_result" then
      result.last_result = v
      return
    end
    if k == "last_query" then
      result.last_query = v
      return
    end
    if k == "last_duration" then
      result.last_duration = v
      return
    end
    if k == "last_conn_name" then
      result.last_conn_name = v
      return
    end
    if k == "last_timestamp" then
      result.last_timestamp = v
      return
    end
    if k == "last_result_width" then
      result.last_result_width = v
      return
    end
    if k == "history_index" then
      query.history_index = v
      return
    end
    rawset(t, k, v)
  end,
})

function M.refresh_result_winbar()
  winbar.refresh_result()
end

function M.refresh_history()
  if M.history_win and vim.api.nvim_win_is_valid(M.history_win) then
    get_history_ui().render()
  end
end

function M.get_active_tab()
  return query.get_active_tab()
end

function M.get_active_connection_context()
  local active_tab = M.get_active_tab()
  local conn_name = active_tab and active_tab.conn_name or nil

  if conn_name then
    local url = connection.get_resolved_url_by_name(conn_name)
    if url then
      return conn_name, url
    end
  end

  local fallback_name = connection.get_active_name()
  local fallback_url = connection.get_active_url()
  return fallback_name, fallback_url
end

function M.switch_tab(index)
  query.switch_tab(index)
end

function M.next_tab()
  query.next_tab()
end

function M.prev_tab()
  query.prev_tab()
end

function M.close_tab()
  query.close_tab()
end

function M.create_new_tab(name, content, conn_name, is_saved)
  return query.create_new_tab(name, content, conn_name, is_saved)
end

function M.show_result(raw, elapsed)
  result.show_result(raw, elapsed)
end

function M.execute_query()
  query.execute_query()
end

function M.save_query_by_buf(buf, callback)
  query.save_query_by_buf(buf, callback)
end

function M.save_current_query(callback)
  query.save_current_query(callback)
end

function M.open_saved_query(query_name, content, conn_name)
  query.open_saved_query(query_name, content, conn_name)
end

function M.setup_result_keymaps()
  keymaps.setup_result_keymaps()
end

function M.setup_editor_keymaps(buf)
  keymaps.setup_editor_keymaps(buf)
end

function M.setup_keymaps()
  keymaps.setup_keymaps()
end

function M.yank_current_row()
  result.yank_current_row()
end

function M.yank_all_rows()
  result.yank_all_rows()
end

function M.open()
  if M.tab_nr and vim.api.nvim_tabpage_is_valid(M.tab_nr) then
    local wins_valid = M.sidebar_win
      and vim.api.nvim_win_is_valid(M.sidebar_win)
      and M.editor_win
      and vim.api.nvim_win_is_valid(M.editor_win)
      and M.result_win
      and vim.api.nvim_win_is_valid(M.result_win)

    if wins_valid then
      local tab_list = vim.api.nvim_list_tabpages()
      for i, tab in ipairs(tab_list) do
        if tab == M.tab_nr then
          vim.cmd("tabnext " .. i)
          return
        end
      end
    end

    M.cleanup()
    pcall(function()
      vim.cmd "tabclose"
    end)
  end

  if M.tab_nr then
    M.cleanup()
  end

  query.delete_existing_buf "[if.db]"

  vim.cmd "tabnew"
  local initial_buf = vim.api.nvim_get_current_buf()
  M.tab_nr = vim.api.nvim_get_current_tabpage()

  local windows = M._build_layout()

  M._init_all_components(windows)

  pcall(vim.api.nvim_buf_delete, initial_buf, { force = true })

  if M.sidebar_win and vim.api.nvim_win_is_valid(M.sidebar_win) then
    vim.api.nvim_set_current_win(M.sidebar_win)
  end

  M._setup_autocmds()
end

---@param windows table<string, number>
---@return table<string, integer>
function M._build_layout()
  local g = geometry()

  local sidebar_win = vim.api.nvim_get_current_win()
  vim.cmd "belowright split"
  local history_win = vim.api.nvim_get_current_win()

  vim.api.nvim_set_current_win(sidebar_win)
  vim.cmd "belowright vsplit"
  local editor_win = vim.api.nvim_get_current_win()

  vim.api.nvim_set_current_win(history_win)
  vim.cmd "belowright vsplit"
  local result_win = vim.api.nvim_get_current_win()

  vim.api.nvim_win_set_height(sidebar_win, g.top)
  vim.api.nvim_win_set_width(sidebar_win, g.left)
  vim.api.nvim_win_set_width(history_win, g.left)

  return { sidebar = sidebar_win, history = history_win, editor = editor_win, result = result_win }
end

---@param windows table<string, integer>
function M._init_all_components(windows)
  local cfg = config.get()

  if windows.sidebar then
    M.sidebar_win = windows.sidebar
    M.sidebar_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(M.sidebar_win, M.sidebar_buf)
    get_sidebar().setup(M.sidebar_buf, M.sidebar_win)
  end

  if windows.editor then
    M.editor_win = windows.editor
    vim.wo[M.editor_win].winbar = ""
    M.create_new_tab(nil, nil, connection.get_active_name(), false)
  end

  if windows.result then
    M.result_win = windows.result
    M.result_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(M.result_win, M.result_buf)
    vim.api.nvim_buf_set_name(M.result_buf, "[if.db] Result")
    vim.bo[M.result_buf].filetype = "ifdb_result"
    vim.bo[M.result_buf].buftype = "nofile"
    vim.bo[M.result_buf].buflisted = false
    vim.bo[M.result_buf].modifiable = false
    vim.wo[M.result_win].cursorline = true
    vim.wo[M.result_win].wrap = false
    vim.wo[M.result_win].number = cfg.result.show_line_number
    vim.wo[M.result_win].relativenumber = false
    M.setup_result_keymaps()
    vim.schedule(function()
      M.refresh_result_winbar()
    end)
  end

  if windows.history then
    M.history_win = windows.history
    M.history_buf = get_history_ui().get_or_create_buf()
    vim.api.nvim_win_set_buf(M.history_win, M.history_buf)
    get_history_ui().setup(M.history_win)
  end
end

function M._setup_autocmds()
  local augroup = vim.api.nvim_create_augroup("IfDbWorkbench", { clear = true })

  vim.api.nvim_create_autocmd("TabClosed", {
    group = augroup,
    callback = function()
      if not vim.api.nvim_tabpage_is_valid(M.tab_nr or 0) then
        M.cleanup()
      end
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    callback = function(ev)
      if M.tab_nr and vim.api.nvim_get_current_tabpage() ~= M.tab_nr then
        return
      end

      local closed_win = tonumber(ev.match)
      if closed_win == M.editor_win then
        M.editor_win = nil
        M.editor_buf = nil
      end
      if closed_win == M.sidebar_win then
        vim.schedule(function()
          if M.tab_nr and vim.api.nvim_tabpage_is_valid(M.tab_nr) then
            pcall(function()
              vim.cmd "tabclose"
            end)
          end
          M.cleanup()
        end)
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = augroup,
    callback = function()
      if M.tab_nr and vim.api.nvim_get_current_tabpage() == M.tab_nr then
        M._resize_layout()
        get_history_ui().render()
        M.refresh_result_winbar()
      end
    end,
  })

  vim.api.nvim_create_autocmd("WinResized", {
    group = augroup,
    callback = function()
      if M.tab_nr and vim.api.nvim_get_current_tabpage() == M.tab_nr then
        get_history_ui().render()
        M.refresh_result_winbar()
      end
    end,
  })
end

function M._resize_layout()
  local g = geometry()

  if M.sidebar_win and vim.api.nvim_win_is_valid(M.sidebar_win) then
    vim.api.nvim_win_set_height(M.sidebar_win, g.top)
    vim.api.nvim_win_set_width(M.sidebar_win, g.left)
  end
  if M.history_win and vim.api.nvim_win_is_valid(M.history_win) then
    vim.api.nvim_win_set_width(M.history_win, g.left)
  end
end

---@param q? string
function M.open_editor(q)
  if not M.tab_nr or not vim.api.nvim_tabpage_is_valid(M.tab_nr) then
    M.open()
  end

  M.create_new_tab(nil, q, connection.get_active_name(), false)

  if M.editor_win and vim.api.nvim_win_is_valid(M.editor_win) then
    vim.api.nvim_set_current_win(M.editor_win)
    vim.cmd "startinsert!"
  end
end

---@param q string
function M.open_editor_with_query(q)
  M.open_editor(q)
end

function M.restore()
  if M.tab_nr and vim.api.nvim_tabpage_is_valid(M.tab_nr) then
    pcall(function()
      vim.cmd "tabclose"
    end)
  end
  M.cleanup()
  M.open()
end

function M.close()
  if M.tab_nr and vim.api.nvim_tabpage_is_valid(M.tab_nr) then
    vim.cmd "tabclose"
  end
  M.cleanup()
end

function M.cleanup()
  get_sidebar().cleanup()
  get_history_ui().cleanup()

  result.cleanup()
  query.cleanup()

  M.tab_nr = nil
  M.sidebar_buf = nil
  M.sidebar_win = nil
  M.editor_buf = nil
  M.editor_win = nil
  M.result_buf = nil
  M.result_win = nil
  M.history_buf = nil
  M.history_win = nil
end

return M
