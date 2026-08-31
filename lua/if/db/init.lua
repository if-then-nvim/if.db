local M = {}

M.config = require "if.db.config"
M.core = require "if.db.core"
M.ui = require "if.db.ui"

---@param opts? IfDb.Config
function M.setup(opts)
  M.config.setup(opts)
  M.ui.highlights.setup()

  local has_cmp, cmp = pcall(require, "cmp")
  if has_cmp then
    cmp.register_source("ifdb", require("cmp_ifdb").new())
  end
end

function M.open()
  M.ui.workbench.open()
end

function M.pick_connection()
  M.ui.picker.open(function(selected)
    if selected then
      M.core.connection.set_active(selected.name)
      vim.notify("[if.db] Connected to: " .. selected.name, vim.log.levels.INFO)
    end
  end)
end

---@param query string
---@return string
function M.execute(query)
  return M.core.executor.execute_active(query)
end

---@param name string
function M.connect(name)
  if M.core.connection.set_active(name) then
    vim.notify("[if.db] Connected to: " .. name, vim.log.levels.INFO)
  else
    vim.notify("[if.db] Connection not found: " .. name, vim.log.levels.ERROR)
  end
end

function M.list_connections()
  local connections = M.core.connection.list_connections()
  if #connections == 0 then
    vim.notify("[if.db] No connections configured", vim.log.levels.WARN)
    return
  end

  local lines = { "Available connections:" }
  for i, conn in ipairs(connections) do
    local active = conn.name == M.core.connection.get_active_name() and " (active)" or ""
    table.insert(lines, string.format("  %d. %s%s", i, conn.name, active))
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

function M.close()
  M.ui.workbench.close()
end

function M.restore()
  M.ui.workbench.restore()
end

return M
