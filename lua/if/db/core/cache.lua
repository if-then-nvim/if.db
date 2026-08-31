local schema = require "if.db.core.schema"
local connection = require "if.db.core.connection"

local M = {}

M.is_loading_flag = false

---@return boolean
function M.is_loading()
  return M.is_loading_flag
end

---@param url? string
---@return string[]
function M.get_table_names_cached(url)
  local target_url = url or connection.get_active_url()
  if not target_url then
    return {}
  end
  return schema.get_cached_table_names(target_url)
end

---@param url? string
---@return IfDb.Column[]
function M.get_all_columns_cached(url)
  local target_url = url or connection.get_active_url()
  if not target_url then
    return {}
  end
  return schema.get_cached_columns(target_url)
end

---@param callback? fun() Called when warmup is complete
---@param url? string
function M.warmup(callback, url)
  if M.is_loading_flag then
    return
  end

  local target_url = url or connection.get_active_url()
  if not target_url then
    return
  end

  M.is_loading_flag = true

  schema.get_schemas_async(target_url, function(schemas, err)
    if err or #schemas == 0 then
      M.is_loading_flag = false
      if callback then
        callback()
      end
      return
    end

    local pending = 0
    local total = #schemas

    if total == 0 then
      M.is_loading_flag = false
      if callback then
        callback()
      end
      return
    end

    for _, sch in ipairs(schemas) do
      schema.get_tables_async(target_url, sch.name, function(_, _)
        pending = pending + 1

        if pending >= total then
          M.is_loading_flag = false
          if callback then
            callback()
          end
        end
      end)
    end
  end)
end

function M.invalidate()
  schema.clear_cache()
end

return M
