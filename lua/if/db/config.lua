local M = {}

---@type IfDb.Config
M.defaults = {
  connections = {},
  executor = "cli",
  layout = {
    top_ratio = 0.4,
    left_width = 0.22,
  },
  sidebar = {
    show_system_schemas = true,
  },
  result = {
    show_line_number = true,
  },
  history = {
    max_entries = 100,
    on_select = "execute",
    persist = true,
    filter_by_connection = true,
  },
  keymaps = {
    execute = "<CR>",
    close = "q",

    sidebar = {
      toggle_expand = { "<CR>", "o" },
      refresh = "R",
      rename = "r",
      new_query = "n",
      copy_name = "y",
      insert_template = "i",
      delete = "d",
      copy_query = "c",
      paste_query = "p",
      to_editor = "<Tab>",
      to_history = "<S-Tab>",
      toggle_types = "t",
    },

    history = {
      select = "<CR>",
      execute = "R",
      copy = "y",
      delete = "d",
      clear = "C",
      to_sidebar = "<Tab>",
      to_result = "<S-Tab>",
    },

    editor = {
      execute_insert = "<C-CR>",
      execute_leader = "<Leader>r",
      save = "<C-s>",
      next_tab = "gt",
      prev_tab = "gT",
      close_tab = "<Leader>w",
      to_result = "<Tab>",
      to_sidebar = "<S-Tab>",
    },

    result = {
      yank_row = "y",
      yank_all = "Y",
      to_sidebar = "<Tab>",
      to_editor = "<S-Tab>",
    },
  },
  highlights = {},
}

---@type IfDb.Config|nil
M.options = nil

---@param opts? IfDb.Config
function M.setup(opts)
  local user_opts = opts or {}
  if user_opts.grid then
    vim.notify("[if.db] 'grid' is deprecated, use 'result' instead.", vim.log.levels.WARN)
    if not user_opts.result then
      user_opts.result = user_opts.grid
    end
    user_opts.grid = nil
  end
  if user_opts.schema then
    vim.notify("[if.db] 'schema' is deprecated, use 'sidebar' instead.", vim.log.levels.WARN)
    user_opts.sidebar = vim.tbl_deep_extend("force", user_opts.sidebar or {}, user_opts.schema)
    user_opts.schema = nil
  end
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, user_opts)

  if type(M.options.layout) ~= "table" then
    vim.notify(
      "[if.db] 'layout' is now a table of proportions, not a preset name. Using defaults.",
      vim.log.levels.WARN
    )
    M.options.layout = vim.deepcopy(M.defaults.layout)
  end
end

---@return IfDb.Config
function M.get()
  if not M.options then
    M.options = vim.tbl_deep_extend("force", {}, M.defaults)
  end
  return M.options
end

return M
