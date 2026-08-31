local M = {}

---@param raw string
---@return IfDb.QueryResult
function M.parse(raw)
  local lines = vim.split(raw, "\n")

  lines = vim.tbl_filter(function(line)
    return not line:match "^mysql: %[Warning%]"
  end, lines)

  local result = {
    columns = {},
    rows = {},
    row_count = 0,
    raw = raw,
  }

  if #lines == 0 then
    result.columns = { "result" }
    return result
  end

  local header_line = lines[1]
  local separator_line = lines[2] or ""

  if header_line:find "\t" then
    result.columns = vim.split(header_line, "\t")
    for i = 2, #lines do
      local line = lines[i]
      if line ~= "" then
        local row = vim.split(line, "\t")
        table.insert(result.rows, row)
      end
    end
    result.row_count = #result.rows
    return result
  end

  if not separator_line:match "^%-" and not separator_line:match "^%+" then
    result.columns = { "result" }
    for _, line in ipairs(lines) do
      if line ~= "" then
        table.insert(result.rows, { line })
      end
    end
    result.row_count = #result.rows
    return result
  end

  local col_positions = {}
  local pos = 1
  for segment in separator_line:gmatch "[%-]+" do
    local start_pos = separator_line:find(segment, pos, true)
    local end_pos = start_pos + #segment - 1
    table.insert(col_positions, { start = start_pos, finish = end_pos })
    pos = end_pos + 1
  end

  for _, col_pos in ipairs(col_positions) do
    local col_name = header_line:sub(col_pos.start, col_pos.finish)
    col_name = vim.trim(col_name)
    table.insert(result.columns, col_name)
  end

  for i = 3, #lines do
    local line = lines[i]

    if line:match "^%(%d+ rows?%)" then
      local count = line:match "%((%d+) rows?%)"
      result.row_count = tonumber(count) or #result.rows
      break
    end

    if line ~= "" then
      local row = {}
      for _, col_pos in ipairs(col_positions) do
        local cell = ""
        if col_pos.start <= #line then
          cell = line:sub(col_pos.start, math.min(col_pos.finish, #line))
          cell = vim.trim(cell)
        end
        table.insert(row, cell)
      end
      table.insert(result.rows, row)
    end
  end

  if result.row_count == 0 then
    result.row_count = #result.rows
  end

  return result
end

---@param result IfDb.QueryResult
---@return number[] Column widths
function M.calculate_column_widths(result)
  local widths = {}

  for i, col in ipairs(result.columns) do
    widths[i] = #col
  end

  for _, row in ipairs(result.rows) do
    for i, cell in ipairs(row) do
      widths[i] = math.max(widths[i] or 0, #cell)
    end
  end

  return widths
end

return M
