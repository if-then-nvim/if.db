local Popup = require "nui.popup"
local event = require("nui.utils.autocmd").event
local parser = require "if.db.utils.parser"
local config = require "if.db.config"

local M = {}

local ns = vim.api.nvim_create_namespace "ifdb_grid"

---@type table|nil
M.current_popup = nil

---@type IfDb.QueryResult|nil
M.current_result = nil

---@type number Current row (1-indexed)
M.cursor_row = 1

---@type number Current column (1-indexed)
M.cursor_col = 1

---@param result IfDb.QueryResult
---@param widths number[]
---@return string[]
local function render_lines(result, widths)
  local lines = {}

  local header = ""
  for i, col in ipairs(result.columns) do
    local padded = col .. string.rep(" ", widths[i] - #col)
    header = header .. " " .. padded .. " "
  end
  table.insert(lines, header)

  for _, row in ipairs(result.rows) do
    local line = ""
    for i, cell in ipairs(row) do
      local w = widths[i] or #cell
      local padded = cell .. string.rep(" ", w - #cell)
      line = line .. " " .. padded .. " "
    end
    table.insert(lines, line)
  end

  return lines
end

---@param raw string Raw query result
---@param elapsed number Execution time in ms
function M.show(raw, elapsed)
  if M.current_popup then
    M.current_popup:unmount()
    M.current_popup = nil
  end

  local result = parser.parse(raw)
  M.current_result = result
  M.cursor_row = 1
  M.cursor_col = 1

  if #result.rows == 0 then
    vim.notify("[if.db] Query returned no data rows", vim.log.levels.INFO)
    return
  end

  local widths = parser.calculate_column_widths(result)
  local lines = render_lines(result, widths)

  local max_line_width = 0
  for _, line in ipairs(lines) do
    max_line_width = math.max(max_line_width, vim.fn.strdisplaywidth(line))
  end

  local opts = config.get()
  local width = math.min(max_line_width + 4, opts.result.max_width, vim.o.columns - 10)
  local height = math.min(#lines + 2, opts.result.max_height, vim.o.lines - 10)

  local popup = Popup {
    position = "50%",
    size = {
      width = width,
      height = height,
    },
    border = {
      style = "single",
      text = {
        top = string.format(" Result: %d rows (%.1fms) ", result.row_count, elapsed),
        top_align = "center",
        bottom = " q:close  j/k:scroll  y:yank row ",
        bottom_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:IfDbBorder,CursorLine:IfDbCellActive",
      cursorline = true,
    },
    buf_options = {
      modifiable = false,
      readonly = true,
      filetype = "ifdb_result",
    },
  }

  M.current_popup = popup
  popup:mount()

  vim.bo[popup.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
  vim.bo[popup.bufnr].modifiable = false

  local total_lines = #lines
  for line_num = 0, total_lines - 1 do
    local row_hl = line_num % 2 == 0 and "IfDbRowOdd" or "IfDbRowEven"
    vim.api.nvim_buf_set_extmark(popup.bufnr, ns, line_num, 0, { end_row = line_num + 1, hl_group = row_hl })
  end

  local byte_pos = 0
  for i, col in ipairs(result.columns) do
    byte_pos = byte_pos + 1
    vim.api.nvim_buf_set_extmark(popup.bufnr, ns, 0, byte_pos, { end_col = byte_pos + #col, hl_group = "IfDbHeader" })
    byte_pos = byte_pos + widths[i] + 1
  end

  vim.api.nvim_win_set_cursor(popup.winid, { 2, 0 })

  M.setup_keymaps(popup)

  popup:on(event.BufLeave, function()
    popup:unmount()
    M.current_popup = nil
  end)
end

---@param popup table NuiPopup instance
function M.setup_keymaps(popup)
  local opts = { noremap = true, silent = true }

  popup:map("n", "q", function()
    popup:unmount()
    M.current_popup = nil
  end, opts)

  popup:map("n", "<Esc>", function()
    popup:unmount()
    M.current_popup = nil
  end, opts)

  popup:map("n", "y", function()
    M.yank_current_row()
  end, opts)

  popup:map("n", "Y", function()
    M.yank_all_rows()
  end, opts)

  popup:map("n", "c", function()
    M.yank_current_row_csv()
  end, opts)
end

function M.yank_current_row()
  if not M.current_result or not M.current_popup then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(M.current_popup.winid)
  local row_idx = cursor[1] - 1

  if row_idx < 1 or row_idx > #M.current_result.rows then
    vim.notify("[if.db] No data row selected", vim.log.levels.WARN)
    return
  end

  local row = M.current_result.rows[row_idx]
  local obj = {}
  for i, col in ipairs(M.current_result.columns) do
    obj[col] = row[i]
  end

  local json = vim.fn.json_encode(obj)
  vim.fn.setreg("+", json)
  vim.fn.setreg('"', json)
  vim.notify("[if.db] Row copied as JSON", vim.log.levels.INFO)
end

function M.yank_current_row_csv()
  if not M.current_result or not M.current_popup then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(M.current_popup.winid)
  local row_idx = cursor[1] - 1

  if row_idx < 1 or row_idx > #M.current_result.rows then
    vim.notify("[if.db] No data row selected", vim.log.levels.WARN)
    return
  end

  local row = M.current_result.rows[row_idx]
  local csv = table.concat(row, ",")
  vim.fn.setreg("+", csv)
  vim.fn.setreg('"', csv)
  vim.notify("[if.db] Row copied as CSV", vim.log.levels.INFO)
end

function M.yank_all_rows()
  if not M.current_result then
    return
  end

  local arr = {}
  for _, row in ipairs(M.current_result.rows) do
    local obj = {}
    for i, col in ipairs(M.current_result.columns) do
      obj[col] = row[i]
    end
    table.insert(arr, obj)
  end

  local json = vim.fn.json_encode(arr)
  vim.fn.setreg("+", json)
  vim.fn.setreg('"', json)
  vim.notify("[if.db] All rows copied as JSON", vim.log.levels.INFO)
end

return M
