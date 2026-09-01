# if.db

A database client for Neovim that shells out to the database's own CLI.
No driver to install, nothing to compile, no daemon: if you can reach a
database from your shell, if.db can reach it too.

PostgreSQL, MySQL, MariaDB and SQLite.

![if.db](./screenshots/hero.webp)

## Requirements

- Neovim >= 0.10
- `psql`, `mysql` or `sqlite3`, for whichever you connect to
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)
- A [Nerd Font](https://www.nerdfonts.com/)

Optional: [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) runs
queries off the main loop; [vim-dadbod](https://github.com/tpope/vim-dadbod)
backs `executor = "dadbod"`.

## Install

```lua
{
  "if-then-nvim/if.db",
  cmd = "IfDb",
  keys = { { "<Leader>db", "<cmd>IfDb<cr>", desc = "Database" } },
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {
    connections = {
      { name = "local", url = "postgres://localhost/mydb" },
      { name = "prod", url = "$DATABASE_URL" },
    },
  },
}
```

`$VAR` and `${VAR}` are expanded when the connection opens, so a password
never has to sit in your config. URLs take the usual shape:

```
postgres://user:password@host:port/database
mysql://user:password@host:port/database
mariadb://user:password@host:port/database
sqlite:///path/to/database.db
```

## Commands

| | |
|---|---|
| `:IfDb` | Open the workbench |
| `:IfDb connect [name]` | Connect, or prompt for a connection |
| `:IfDb pick` | Prompt for a connection |
| `:IfDb list` | List the configured connections |
| `:IfDb query <sql>` | Run one query and echo the result |
| `:IfDbClose` | Close the workbench |
| `:IfDbRestore` | Rebuild the layout |

## Layout

```
┌──────────────┬─────────────────────────────────────┐
│ schema       │ query                               │
├──────────────┼─────────────────────────────────────┤
│ history      │ result                              │
└──────────────┴─────────────────────────────────────┘
```

Reference on the left, work on the right. The arrangement is fixed; the
proportions are yours:

```lua
layout = {
  top_ratio = 0.4,     -- height of the schema and query row
  left_width = 0.22,   -- width of the schema and history column
},
```

## History

Each query is recorded with its timing, written in a shorthand rather
than echoing the SQL already on screen beside it:

![history pane](./screenshots/history.webp)

A verb, the table it touched, then a marker per clause. A marker carries
a value only when the value is what tells you which query this was: the
column a `WHERE` filters on, the table a `JOIN` reaches for, the count a
`LIMIT` stops at. `ORDER BY` shows direction alone and `GROUP BY`
nothing, because the column names are long and rarely what you are
looking for.

## Keymaps

`<Tab>` and `<S-Tab>` move between panes — `<S-Tab>` cycles all four —
`q` closes, and `?` lists the keymaps for the pane you are in.

| Schema | |
|---|---|
| `<CR>` `o` | Expand or collapse, or open a query |
| `n` `r` `d` | New, rename, delete a saved query |
| `y` `c` `p` | Copy name, copy SQL, paste SQL |
| `i` | Open a SELECT for the table, or the column name |
| `t` `R` | Toggle column types, refresh the schema |

| Query | |
|---|---|
| `<CR>` `<Leader>r` | Execute, `<C-CR>` from insert mode |
| `<C-s>` | Save |
| `gt` `gT` `<Leader>w` | Next, previous, close |

| History | |
|---|---|
| `<CR>` | Load or execute, per `history.on_select` |
| `R` | Execute again |
| `y` `d` `C` | Copy, delete, clear all |

| Result | |
|---|---|
| `y` `Y` | Yank the row, or every row, as JSON |

All remappable under `keymaps`, grouped by pane. See
`:help if-db-keymaps`.

## Completion

The plugin registers an `ifdb` source offering tables, columns and
keywords from the schema you are querying.

```lua
-- nvim-cmp
sources = { { name = "ifdb" } }

-- blink.cmp
sources = {
  default = { "lsp", "path", "snippets", "buffer", "ifdb" },
  providers = { ifdb = { name = "ifdb", module = "blink_ifdb" } },
}
```

## Configuration

Every key below is a default; pass only what you want to change.

```lua
require("if.db").setup {
  connections = {},
  executor = "cli",   -- or "dadbod"

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
    on_select = "execute",     -- or "load"
    persist = true,
    filter_by_connection = true,
  },

  keymaps = {},       -- :help if-db-keymaps
  highlights = {},    -- override any IfDb* group
}
```

Saved queries and history live under `stdpath("data")/if.db`.

## Highlights

Result values are coloured by type — NULL, number, string, boolean,
datetime, UUID, JSON — and the history shorthand borrows the colours
tree-sitter gives SQL, so a verb, a table and a column read the same in
both panes. Row stripes are computed from your `Normal` background: they
move away from whichever end of the scale your theme sits at, keeping the
hue you started with.

Override any group through `highlights`, or define it before `setup()`:

```lua
highlights = {
  IfDbHeader = { bg = "#ff6600", fg = "#000000" },
  IfDbNull = { fg = "#555555", italic = true },
}
```

`:help if-db-highlights` lists every group and its default.

## Development

```sh
make test                                  # all specs
make test-file FILE=tests/core/schema_spec.lua
make lint                                  # stylua --check + selene
make format
```

## Credits

- [vim-dadbod-ui](https://github.com/kristijanhusak/vim-dadbod-ui), the
  classic DB UI for Vim and Neovim
- [nvim-dbee](https://github.com/kndndrj/nvim-dbee), a modern take on the
  same problem

if.db is the lightweight corner of that space: no driver, no daemon, just
the CLI you already have.
