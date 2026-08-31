if vim.g.loaded_ifdb then
  return
end
vim.g.loaded_ifdb = true

vim.api.nvim_create_user_command("IfDb", function(opts)
  local ifdb = require "if.db"
  local args = opts.fargs

  if #args == 0 then
    ifdb.open()
    return
  end

  local subcmd = args[1]

  if subcmd == "connect" then
    if args[2] then
      ifdb.connect(args[2])
    else
      ifdb.pick_connection()
    end
  elseif subcmd == "pick" then
    ifdb.pick_connection()
  elseif subcmd == "list" then
    ifdb.list_connections()
  elseif subcmd == "query" or subcmd == "q" then
    local query = table.concat(vim.list_slice(args, 2), " ")
    if query == "" then
      vim.notify("[if.db] Usage: :IfDb query <sql>", vim.log.levels.WARN)
      return
    end
    local result = ifdb.execute(query)
    if result ~= "" then
      print(result)
    end
  else
    vim.notify("[if.db] Unknown subcommand: " .. subcmd, vim.log.levels.ERROR)
  end
end, {
  nargs = "*",
  complete = function(arg_lead, cmd_line, _)
    local args = vim.split(cmd_line, "%s+")
    if #args <= 2 then
      local subcommands = { "connect", "pick", "list", "query" }
      return vim.tbl_filter(function(s)
        return s:match("^" .. arg_lead)
      end, subcommands)
    elseif args[2] == "connect" then
      local ifdb = require "if.db"
      local connections = ifdb.core.connection.list_connections()
      local names = vim.tbl_map(function(c)
        return c.name
      end, connections)
      return vim.tbl_filter(function(s)
        return s:match("^" .. arg_lead)
      end, names)
    end
    return {}
  end,
  desc = "Database client for Neovim",
})

vim.api.nvim_create_user_command("IfDbClose", function()
  require("if.db").close()
end, {
  desc = "Close the IfDb workbench",
})

vim.api.nvim_create_user_command("IfDbRestore", function()
  require("if.db").restore()
end, {
  desc = "Restore the IfDb workbench layout",
})
