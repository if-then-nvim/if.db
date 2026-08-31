local icons = require "if.db.ui.icons"

local M = {}

local workbench
local result

function M.setup(workbench_ref, result_ref)
  workbench = workbench_ref
  result = result_ref
end

local function get_textoff(win)
  local wininfo = vim.fn.getwininfo(win)
  if wininfo and wininfo[1] then
    return wininfo[1].textoff or 0
  end
  return 0
end

---@param ms number|nil
---@return string
local function format_duration(ms)
  if not ms then
    return ""
  end
  if ms < 1000 then
    return string.format("%dms", math.floor(ms))
  elseif ms < 60000 then
    return string.format("%.1fs", ms / 1000)
  else
    return string.format("%.1fm", ms / 60000)
  end
end

function M.refresh_result()
  if not workbench.result_win or not vim.api.nvim_win_is_valid(workbench.result_win) then
    return
  end

  local indent = string.rep(" ", get_textoff(workbench.result_win))
  local label = "%#IfDbHistoryHeader#" .. icons.result .. " Result%*"

  local meta = {}
  if result.last_result and result.last_result.row_count then
    meta[#meta + 1] = "%#IfDbNumber#" .. result.last_result.row_count .. "%* %#Comment#rows%*"
  end
  if result.last_duration then
    meta[#meta + 1] = "%#Comment#" .. format_duration(result.last_duration) .. "%*"
  end

  if #meta == 0 then
    vim.wo[workbench.result_win].winbar = indent .. label
    return
  end

  vim.wo[workbench.result_win].winbar = indent .. label .. "%=" .. table.concat(meta, " %#NonText#·%* ") .. " "
end

return M
