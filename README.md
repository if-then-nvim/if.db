# if.db

A lightweight database client for Neovim. Query databases directly from your editor.

![if.db](./screenshots/main.png)

## Features

- **Multi-database support**: PostgreSQL, MySQL, MariaDB, SQLite
- **Schema browser**: Navigate schemas, tables, and columns in the sidebar
- **Query editor**: Write and execute SQL with syntax highlighting
- **Query history**: Executed queries in a symbolic shorthand, with timing
- **Multiple queries**: Several queries open at once, listed in the sidebar
- **Save queries**: Store frequently used queries per connection
- **Result viewer**: Table with zebra striping and type-aware highlighting

## Layout

```
┌──────────────┬──────────────────────┬──────────────┐
│ schema       │ query                │ history      │
├──────────────┴──────────────────────┴──────────────┤
│ result                                             │
└─────────────────────────────────────────────────────┘
```

The arrangement is fixed. Proportions are yours:

```lua
layout = {
  top_ratio = 0.4,       -- top strip height
  schema_width = 0.22,   -- of the screen
  history_width = 0.28,  -- of the screen, never under 36 columns
},
```

The query pane takes what is left, never under 30 columns. Results run
the full width, which is what a table wants.

## Requirements

- Neovim >= 0.9.0
- Database CLI tools:
  - `psql` for PostgreSQL
  - `mysql` for MySQL/MariaDB
  - `sqlite3` for SQLite
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)
- [vim-dadbod](https://github.com/tpope/vim-dadbod) (optional: for `executor = "dadbod"`)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (optional: for async execution)

## Installation

### lazy.nvim

```lua
{
  "if-then-end/if.db",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",       -- Optional: for async execution
    "tpope/vim-dadbod",            -- Optional: for executor = "dadbod"
    "hrsh7th/nvim-cmp",            -- Optional: for nvim-cmp autocompletion
  },
  -- For blink.cmp, the source is included in this plugin (blink_ifdb)
  config = function()
    require("if.db").setup({
      connections = {
        { name = "local", url = "postgres://user:pass@localhost:5432/mydb" },
        { name = "prod", url = "$DATABASE_URL" }, -- supports env vars
      },
    })
  end,
}
```

## Autocompletion (Optional)

### nvim-cmp

If you use `nvim-cmp`, add `ifdb` to your sources to enable SQL autocompletion (tables, columns, keywords):

```lua
require("cmp").setup({
  sources = {
    { name = "if.db" },
    -- other sources...
  },
})
```

### blink.cmp

If you use `blink.cmp`, add `ifdb` to your sources:

```lua
require("blink.cmp").setup({
  sources = {
    default = { "lsp", "path", "snippets", "buffer", "if.db" },
    providers = {
      ifdb = {
        name = "if.db",
        module = "blink_ifdb",
      },
    },
  },
})
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:IfDb` | Open the if.db sidebar |
| `:IfDbClose` | Close if.db |

### Sidebar Keymaps

| Key | Action |
|-----|--------|
| `<CR>` / `o` | Toggle node / Open query |
| `<Tab>` | Move to editor |
| `S` | Select table (SELECT *) |
| `i` | Insert table (INSERT template) |
| `d` | Delete saved query |
| `q` | Close |

### Editor Keymaps

| Key | Action |
|-----|--------|
| `<CR>` | Execute query |
| `<C-s>` | Save query |
| `gt` / `gT` | Next / Previous tab |
| `<Leader>w` | Close tab |
| `<Tab>` | Move to result |
| `q` | Close |

### History Keymaps

| Key | Action |
|-----|--------|
| `<CR>` | Load or execute query (based on config) |
| `R` | Re-execute query immediately |
| `y` | Copy query to clipboard |
| `d` | Delete entry |
| `C` | Clear all history |
| `<Tab>` | Move to sidebar |
| `<S-Tab>` | Move to result |
| `q` | Close |

### Result Keymaps

| Key | Action |
|-----|--------|
| `y` | Yank current row as JSON |
| `Y` | Yank all rows as JSON |
| `<Tab>` | Move to sidebar |
| `<S-Tab>` | Move to editor |
| `q` | Close |

## Screenshots

### Schema Browser
![Schema Browser](./screenshots/sidebar.png)

### Query Result with Type Highlighting
![Result Viewer](./screenshots/result.png)

### Query History
![Query History](./screenshots/history.png)

## Configuration

```lua
require("if.db").setup({
  connections = {
    { name = "local", url = "postgres://localhost/mydb" },
  },
  executor = "cli",    -- "cli" (self-contained) | "dadbod" (requires vim-dadbod)
  layout = {
    top_ratio = 0.4,
    schema_width = 0.22,
    history_width = 0.28,
  },
  sidebar = {
    show_system_schemas = true,
  },
  result = {
    max_width = 120,
    max_height = 20,
    show_line_number = true,
  },
  history = {
    max_entries = 100,
    on_select = "execute",    -- "execute" or "load"
    persist = true,
    filter_by_connection = true,
  },
  keymaps = {
    open = "<Leader>db",
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
  highlights = {
    -- Override any IfDb highlight group
    -- IfDbHeader = { bg = "#ff6600", fg = "#000000" },
  },
})
```

### History

Executed queries are written in a shorthand rather than echoed back, since
the query itself is in the editor above:

```
10:35  SEL stories ⋈ users ↓ ⊞     53ms ×2
       SEL users                      31ms
10:34  SEL users ↑                 50ms ×3
```

| Symbol | Meaning |
|--------|---------|
| `?` | `WHERE` |
| `⋈ name` | `JOIN name` |
| `↑` `↓` | `ORDER BY`, ascending or descending |
| `⊞` | `GROUP BY` |
| `⊤n` | `LIMIT n` |

The timestamp prints only when it changes, adjacent repeats of the same
query collapse into one row with a count, and the timing is laid out from
the right edge so it survives a narrow pane.

## Highlight Groups

All highlight groups can be overridden by defining them before `setup()`.
Groups marked with **(computed)** are always recalculated based on your colorscheme.

### Result

| Group | Default | Description |
|-------|---------|-------------|
| `IfDbRowOdd` | **(computed)** | Odd row background |
| `IfDbRowEven` | **(computed)** | Even row background |
| `IfDbHeader` | **(computed)** | Result header (from `Function` fg) |
| `IfDbSeparator` | `Comment` | Result separator lines |
| `IfDbCellActive` | `CursorLine` | Active cell |

### Window

| Group | Default | Description |
|-------|---------|-------------|
| `IfDbFloat` | `NormalFloat` | Float window background |
| `IfDbBorder` | `WinSeparator` | Window border |
| `IfDbTitle` | `Title` | Window title |

### Data Types

| Group | Default | Description |
|-------|---------|-------------|
| `IfDbNull` | `Comment` | NULL values |
| `IfDbNumber` | `Number` | Numeric values |
| `IfDbString` | `Normal` | String values |
| `IfDbBoolean` | `Boolean` | Boolean values |
| `IfDbDateTime` | `Special` | Date/time values |
| `IfDbUuid` | `Constant` | UUID values |
| `IfDbJson` | `Function` | JSON values |

### Schema

| Group | Default | Description |
|-------|---------|-------------|
| `IfDbTable` | `Type` | Table names |
| `IfDbKey` | `Keyword` | Key names |
| `IfDbPK` | `ErrorMsg` | Primary key (bold) |
| `IfDbFK` | `Function` | Foreign key (bold) |

### Sidebar

| Group | Default | Description |
|-------|---------|-------------|
| `IfDbIconDb` | `Number` | DB icon colour when the type is unknown |
| `IfDbIconPostgres` | `fg=#4169E1` | PostgreSQL brand color (bold) |
| `IfDbIconMysql` | `fg=#4479A1` | MySQL brand color (bold) |
| `IfDbIconMariadb` | `fg=#003545` | MariaDB brand color (bold) |
| `IfDbIconSqlite` | `fg=#003B57` | SQLite brand color (bold) |
| `IfDbIconRedis` | `fg=#FF4438` | Redis brand color (bold) |
| `IfDbIconMongodb` | `fg=#47A248` | MongoDB brand color (bold) |
| `IfDbSidebarIconConnection` | `Number` | Connection icon |
| `IfDbSidebarIconActive` | `String` | Active connection icon |
| `IfDbSidebarIconNewQuery` | `Function` | New query icon |
| `IfDbSidebarIconBuffers` | `Function` | Buffers icon |
| `IfDbSidebarIconSaved` | `Keyword` | Saved queries icon |
| `IfDbSidebarIconSchemas` | `Special` | Schemas icon |
| `IfDbSidebarIconSchema` | `Type` | Schema icon |
| `IfDbSidebarIconTable` | `Type` | Table icon |
| `IfDbSidebarIconColumn` | `Function` | Column icon |
| `IfDbSidebarIconPK` | `ErrorMsg` | Primary key icon |
| `IfDbSidebarText` | `Normal` | Default text |
| `IfDbSidebarTextActive` | `String` | Active item text (bold) |
| `IfDbSidebarType` | `Comment` | Type annotation |

### History

| Group | Default | Description |
|-------|---------|-------------|
| `IfDbHistoryHeader` | `Title` | Section header (bold) |
| `IfDbHistoryRowOdd` | **(computed)** | Odd row background |
| `IfDbHistoryRowEven` | **(computed)** | Even row background |
| `IfDbHistoryTime` | `Comment` | Timestamp |
| `IfDbHistoryVerb` | `Keyword` | SQL verb |
| `IfDbHistoryTarget` | `Type` | Target table name |
| `IfDbHistoryDuration` | `Number` | Execution duration |
| `IfDbHistoryConnName` | `Normal` | Connection name |
| `IfDbHistorySelect` | `Function` | SELECT queries |
| `IfDbHistoryInsert` | `String` | INSERT queries |
| `IfDbHistoryUpdate` | `Type` | UPDATE queries |
| `IfDbHistoryDelete` | `ErrorMsg` | DELETE queries |
| `IfDbHistoryCreate` | `String` | CREATE statements |
| `IfDbHistoryDrop` | `ErrorMsg` | DROP statements |
| `IfDbHistoryAlter` | `Special` | ALTER statements |
| `IfDbHistoryTruncate` | `WarningMsg` | TRUNCATE statements |

Hint badges (compact mode):

| Group | Default | Description |
|-------|---------|-------------|
| `IfDbHistoryHintWhere` | `WarningMsg` | WHERE clause |
| `IfDbHistoryHintJoin` | `Special` | JOIN clause |
| `IfDbHistoryHintOrder` | `Keyword` | ORDER BY |
| `IfDbHistoryHintGroup` | `Type` | GROUP BY |
| `IfDbHistoryHintLimit` | `Number` | LIMIT |

### Tab Bar

| Group | Default | Description |
|-------|---------|-------------|
| `IfDbTabActive` | `bg=#3a3a4a` | Active tab (bold) |
| `IfDbTabActiveIcon` | `bg=#3a3a4a fg=#a6e3a1` | Active tab icon |
| `IfDbTabInactive` | `Comment` | Inactive tab |
| `IfDbTabInactiveIcon` | `Comment` | Inactive tab icon |
| `IfDbTabModified` | `WarningMsg` | Modified indicator |
| `IfDbTabIconSaved` | `String` | Saved query icon |
| `IfDbTabIconUnsaved` | `Function` | Unsaved query icon |
| `IfDbTabbarBg` | `Normal` | Tab bar background |

### Customization

Override highlights via `setup()`:

```lua
require("if.db").setup({
  highlights = {
    IfDbHeader = { bg = "#ff6600", fg = "#000000" },
    IfDbNull = { fg = "#555555", italic = true },
  },
})
```

## Connection URL Format

```
postgres://user:password@host:port/database
mysql://user:password@host:port/database
mariadb://user:password@host:port/database
sqlite:///path/to/database.db
```

Environment variables are supported: `$DATABASE_URL` or `${DATABASE_URL}`

## Acknowledgements

This project was inspired by excellent existing plugins:

- [vim-dadbod-ui](https://github.com/kristijanhusak/vim-dadbod-ui): The classic DB UI for Vim/Neovim.
- [nvim-dbee](https://github.com/kndndrj/nvim-dbee): A modern approach to DB client in Neovim.

`if.db` aims to provide a lightweight, self-contained alternative with a modern Lua-based UI. It can optionally integrate with [vim-dadbod](https://github.com/tpope/vim-dadbod) via `executor = "dadbod"`.

## License

MIT
