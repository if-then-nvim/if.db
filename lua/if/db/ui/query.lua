local executor = require "if.db.core.executor"
local connection = require "if.db.core.connection"
local parser = require "if.db.utils.parser"
local storage = require "if.db.core.storage"
local query_history = require "if.db.core.history"

local function get_history_ui()
  return require "if.db.ui.history"
end

local function get_sidebar()
  return require "if.db.ui.sidebar"
end

local M = {}

local workbench

function M.setup(workbench_ref)
  workbench = workbench_ref
end

---@type string[]
M.history = {}

---@type number
M.history_index = 0

---@param buf number
---@param callback? fun(success: boolean)
function M.save_query_by_buf(buf, callback)
  local tab = nil
  for _, t in ipairs(workbench.query_tabs) do
    if t.buf == buf then
      tab = t
      break
    end
  end
  if not tab then
    if callback then
      callback(false)
    end
    return
  end

  local conn_name = tab.conn_name or connection.get_active_name()
  if not conn_name then
    vim.notify("[if.db] No connection for query", vim.log.levels.WARN)
    if callback then
      callback(false)
    end
    return
  end

  local lines = vim.api.nvim_buf_get_lines(tab.buf, 0, -1, false)
  local content = table.concat(lines, "\n")

  local function do_save(name)
    local ok, err = storage.save_query(conn_name, name, content)
    if ok then
      tab.name = name
      tab.modified = false
      tab.is_saved = true
      require("if.db.ui.sidebar").refresh()
      vim.notify("[if.db] Saved: " .. name, vim.log.levels.INFO)
      if callback then
        callback(true)
      end
    else
      vim.notify("[if.db] Save failed: " .. (err or "unknown"), vim.log.levels.ERROR)
      if callback then
        callback(false)
      end
    end
  end

  if tab.is_saved then
    do_save(tab.name)
  else
    vim.schedule(function()
      vim.ui.input({
        prompt = "Query name: ",
        default = tab.name:match "^query%-" and "" or tab.name,
      }, function(input)
        if input and input ~= "" then
          if storage.query_exists(conn_name, input) then
            vim.ui.select({ "Overwrite", "Cancel" }, {
              prompt = "Query '" .. input .. "' already exists",
            }, function(choice)
              if choice == "Overwrite" then
                do_save(input)
              else
                if callback then
                  callback(false)
                end
              end
            end)
          else
            do_save(input)
          end
        else
          if callback then
            callback(false)
          end
        end
      end)
    end)
  end
end

---@param callback? fun(success: boolean)
function M.save_current_query(callback)
  local tab = workbench.get_active_tab()
  if not tab then
    vim.notify("[if.db] No active query tab", vim.log.levels.WARN)
    if callback then
      callback(false)
    end
    return
  end
  M.save_query_by_buf(tab.buf, callback)
end

---@param query_name string
---@param content string
---@param conn_name string
function M.open_saved_query(query_name, content, conn_name)
  if not workbench.tab_nr or not vim.api.nvim_tabpage_is_valid(workbench.tab_nr) then
    workbench.open()
  end

  for i, tab in ipairs(workbench.query_tabs) do
    if tab.name == query_name and tab.conn_name == conn_name and tab.is_saved then
      workbench.switch_tab(i)
      if workbench.editor_win and vim.api.nvim_win_is_valid(workbench.editor_win) then
        vim.api.nvim_set_current_win(workbench.editor_win)
      end
      return
    end
  end

  workbench.create_new_tab(query_name, content, conn_name, true)

  if workbench.editor_win and vim.api.nvim_win_is_valid(workbench.editor_win) then
    vim.api.nvim_set_current_win(workbench.editor_win)
  end
end

function M.execute_query()
  if not workbench.editor_buf or not vim.api.nvim_buf_is_valid(workbench.editor_buf) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(workbench.editor_buf, 0, -1, false)
  local query = table.concat(lines, "\n")
  query = vim.trim(query)

  if query == "" then
    vim.notify("[if.db] Empty query", vim.log.levels.WARN)
    return
  end

  local url = connection.get_active_url()
  if not url then
    vim.notify("[if.db] No active connection", vim.log.levels.WARN)
    return
  end

  table.insert(M.history, 1, query)
  if #M.history > 100 then
    table.remove(M.history)
  end
  M.history_index = 0

  local start_time = vim.uv.hrtime()
  local result = executor.execute(url, query)
  local elapsed = (vim.uv.hrtime() - start_time) / 1e6

  local parsed_result = parser.parse(result)
  query_history.add {
    query = query,
    timestamp = os.time(),
    conn_name = connection.get_active_name() or "unknown",
    duration_ms = elapsed,
    row_count = parsed_result and parsed_result.row_count or 0,
  }

  if workbench.history_win and vim.api.nvim_win_is_valid(workbench.history_win) then
    get_history_ui().render()
  end

  local result_mod = require "if.db.ui.result"
  result_mod.last_query = query
  result_mod.last_duration = elapsed
  result_mod.last_conn_name = connection.get_active_name()
  result_mod.last_timestamp = os.time()
  result_mod.show_result(result, elapsed)
end

---@return number|nil
local function delete_existing_buf(name)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name:match(vim.pesc(name)) then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end
end

M.delete_existing_buf = delete_existing_buf

function M.cleanup()
  M.history = {}
  M.history_index = 0
  M.cleanup_tabs()
end

---@type IfDb.QueryTab[]
M.query_tabs = {}

---@type integer
M.active_tab = 0

---@return IfDb.QueryTab|nil
function M.get_active_tab()
  if M.active_tab > 0 and M.active_tab <= #M.query_tabs then
    return M.query_tabs[M.active_tab]
  end
  return nil
end

---@param index integer
function M.switch_tab(index)
  if index < 1 or index > #M.query_tabs then
    return
  end

  M.active_tab = index
  local tab = M.query_tabs[index]

  if workbench.editor_win and vim.api.nvim_win_is_valid(workbench.editor_win) then
    vim.api.nvim_win_set_buf(workbench.editor_win, tab.buf)
    workbench.editor_buf = tab.buf
  end

  local conn_name = tab.conn_name or connection.get_active_name() or "no connection"
  local display_name = tab.is_saved and tab.name or ("*" .. tab.name)
  pcall(vim.api.nvim_buf_set_name, tab.buf, "[if.db] " .. display_name .. " - " .. conn_name)

  get_sidebar().refresh()
end

function M.next_tab()
  if #M.query_tabs == 0 then
    return
  end
  M.switch_tab(M.active_tab % #M.query_tabs + 1)
end

function M.prev_tab()
  if #M.query_tabs == 0 then
    return
  end
  M.switch_tab((M.active_tab - 2) % #M.query_tabs + 1)
end

local function do_close_tab()
  local closing = M.query_tabs[M.active_tab].buf

  table.remove(M.query_tabs, M.active_tab)

  if #M.query_tabs == 0 then
    M.create_new_tab()
  else
    M.active_tab = math.min(M.active_tab, #M.query_tabs)
    M.switch_tab(M.active_tab)
  end

  if closing and vim.api.nvim_buf_is_valid(closing) then
    pcall(vim.api.nvim_buf_delete, closing, { force = true })
  end
end

function M.close_tab()
  if #M.query_tabs == 0 then
    return
  end

  local tab = M.query_tabs[M.active_tab]
  if not tab.modified then
    do_close_tab()
    return
  end

  vim.ui.select({ "Save", "Don't Save", "Cancel" }, {
    prompt = "Save changes to '" .. tab.name .. "'?",
  }, function(choice)
    if choice == "Save" then
      M.save_current_query(function(success)
        if success then
          do_close_tab()
        end
      end)
    elseif choice == "Don't Save" then
      do_close_tab()
    end
  end)
end

---@param name? string
---@param content? string
---@param conn_name? string
---@param is_saved? boolean
---@return integer tab_index
function M.create_new_tab(name, content, conn_name, is_saved)
  local buf = vim.api.nvim_create_buf(false, true)
  local conn = conn_name or connection.get_active_name() or "no connection"

  local tab_name = name
  if not tab_name then
    local count = 1
    for _, t in ipairs(M.query_tabs) do
      if t.name:match "^query%-" then
        count = count + 1
      end
    end
    tab_name = "query-" .. count
  end

  ---@type IfDb.QueryTab
  local tab = {
    buf = buf,
    name = tab_name,
    conn_name = conn,
    modified = false,
    is_saved = is_saved or false,
  }

  table.insert(M.query_tabs, tab)
  M.active_tab = #M.query_tabs

  vim.bo[buf].filetype = "sql"
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].swapfile = false

  local display_name = is_saved and tab_name or ("*" .. tab_name)
  pcall(vim.api.nvim_buf_set_name, buf, "[if.db] " .. display_name .. " - " .. conn)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content and vim.split(content, "\n") or { "" })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      M.save_query_by_buf(buf, function(success)
        if success then
          vim.bo[buf].modified = false
        end
      end)
    end,
  })

  vim.api.nvim_buf_attach(buf, false, {
    on_lines = function()
      for _, t in ipairs(M.query_tabs) do
        if t.buf == buf and not t.modified then
          t.modified = true
          vim.schedule(function()
            get_sidebar().refresh()
          end)
          break
        end
      end
    end,
  })

  if workbench.editor_win and vim.api.nvim_win_is_valid(workbench.editor_win) then
    vim.api.nvim_win_set_buf(workbench.editor_win, buf)
    workbench.editor_buf = buf
  end

  workbench.setup_editor_keymaps(buf)

  get_sidebar().refresh()

  return #M.query_tabs
end

function M.cleanup_tabs()
  for _, tab in ipairs(M.query_tabs) do
    if tab.buf and vim.api.nvim_buf_is_valid(tab.buf) then
      pcall(vim.api.nvim_buf_delete, tab.buf, { force = true })
    end
  end
  M.query_tabs = {}
  M.active_tab = 0
end

return M
