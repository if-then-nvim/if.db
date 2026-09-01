# if.db

A database client for Neovim that shells out to the database's own CLI.
There is no driver to install, nothing to compile, and no daemon to keep
running — if you can already reach a database from your shell, if.db can
reach it too.

PostgreSQL, MySQL, MariaDB and SQLite.

![if.db](./screenshots/hero.webp)

## Requirements

- Neovim >= 0.10
- The CLI for whichever database you connect to: `psql`, `mysql` or
  `sqlite3`
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)
- A [Nerd Font](https://www.nerdfonts.com/), for the icons in every pane

Optional: [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) runs
queries off the main loop, so a slow one does not block the editor;
without it they run synchronously. [vim-dadbod](https://github.com/tpope/vim-dadbod)
lets you set `executor = "dadbod"` and reuse its adapters instead of the
CLI invocation if.db builds itself.

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

## Connections

A connection is a name and a URL. The URL takes the usual shape, and
`$VAR` or `${VAR}` is expanded when the connection is opened, so a
password never has to sit in your config:

```
postgres://user:password@host:port/database
mysql://user:password@host:port/database
mariadb://user:password@host:port/database
sqlite:///path/to/database.db
```

Building the list at runtime works too, which is the easy way to keep
credentials in the environment and out of version control:

```lua
opts = function()
  local list = {}
  for _, name in ipairs { "local", "staging", "prod" } do
    local url = os.getenv("DB_" .. name:upper())
    if url and url ~= "" then
      list[#list + 1] = { name = name, url = url }
    end
  end
  return { connections = list }
end,
```

## Commands

| Command | |
|---|---|
| `:IfDb` | Open the workbench, or switch to its tab |
| `:IfDb connect [name]` | Connect to a connection, or prompt for one |
| `:IfDb pick` | Prompt for a connection |
| `:IfDb list` | List the configured connections |
| `:IfDb query <sql>` | Run one query and echo the result, no workbench |
| `:IfDbClose` | Close the workbench |
| `:IfDbRestore` | Rebuild the layout after a window was closed |

## Layout

```
┌──────────────┬─────────────────────────────────────┐
│ schema       │ query                               │
├──────────────┼─────────────────────────────────────┤
│ history      │ result                              │
└──────────────┴─────────────────────────────────────┘
```

Reference on the left, work on the right. Two dividers, each running the
full width or the full height, so nothing sits at a ragged offset. The
arrangement is fixed; the proportions are yours:

```lua
layout = {
  top_ratio = 0.4,     -- height of the schema and query row
  left_width = 0.22,   -- width of the schema and history column
},
```

The left column never goes under 36 columns, which is what the history
shorthand needs to stay on one line, and never over half the screen. The
right column keeps 40, and no pane goes under 3 rows, so a small window
degrades instead of collapsing.

`<Tab>` and `<S-Tab>` walk the four panes in a ring. `?` in any of them
lists that pane's keymaps.

## Schema

The sidebar lists connections, open query buffers, saved queries and the
schema tree. Expand down to a column with `<CR>`; `t` toggles column
types on and off.

`i` on a table opens a new query tab holding `SELECT * FROM table LIMIT
10;`, and on a column one holding the column name — enough to start
typing rather than reaching back for the schema you just looked at.

Saved queries live per connection and are yours to name: `n` creates one,
`r` renames, `d` deletes, `c` and `p` copy and paste the SQL between
them.

## History

Every query that runs is recorded with its timing. The pane writes each
one in a shorthand rather than echoing the SQL, which is already on
screen in the editor beside it:

![history pane](./screenshots/history.webp)

A verb, the table it touched, then a marker per clause. Each marker shows
its value only when the value is what tells you which query this was:

| Clause | Shown |
|---|---|
| `WHERE` | the column it filters on |
| `JOIN` | the table it reaches for |
| `ORDER BY` | direction only, ascending or descending |
| `GROUP BY` | nothing |
| `LIMIT` | the row count |

Sort and group columns are left off. Knowing a query was sorted rarely
helps you find it again, and the column names are long enough to push
everything else off the line.

Markers are never half-drawn. When the pane is too narrow a table or
column name truncates with an ellipsis, and a marker that will not fit
whole is dropped rather than left as a stub. The timing is laid out from
the right edge inward, so a narrow pane eats the query text and keeps the
number you were looking for.

`<CR>` runs the entry again, or loads it into the editor without running
it if you set `history.on_select = "load"`. `R` always runs it.

## Result

Columns are sized to their contents and values are coloured by type, so
the shape of a row reads before you have parsed any of it: NULL, number,
string, boolean, datetime, UUID and JSON each get their own group. Rows
alternate against a zebra stripe derived from your `Normal`
background: the stripe moves away from whichever end of the scale your 
theme sits at, so a light colorscheme darkens where a dark one
lightens, and the hue you started with is the hue you keep.

`y` yanks the row under the cursor as JSON, `Y` yanks every row.

## Keymaps

`q` closes the workbench from any pane, `?` shows that pane's keymaps.

| Schema | |
|---|---|
| `<CR>` `o` | Expand or collapse, or open a query |
| `n` `r` `d` | New, rename, delete a saved query |
| `y` `c` `p` | Copy name, copy SQL, paste SQL |
| `i` | Open a SELECT for the table, or the column name |
| `t` | Show or hide column types |
| `R` | Refresh the schema |
| `<Tab>` `<S-Tab>` | Query, history |

| Query | |
|---|---|
| `<CR>` | Execute |
| `<C-CR>` | Execute from insert mode |
| `<Leader>r` | Execute |
| `<C-s>` | Save |
| `gt` `gT` | Next, previous query |
| `<Leader>w` | Close query |
| `<Tab>` `<S-Tab>` | Result, schema |

| History | |
|---|---|
| `<CR>` | Load or execute, per `history.on_select` |
| `R` | Execute again |
| `y` `d` `C` | Copy, delete, clear all |
| `<Tab>` `<S-Tab>` | Schema, result |

| Result | |
|---|---|
| `y` `Y` | Yank the row, or every row, as JSON |
| `<Tab>` `<S-Tab>` | Schema, query |

Every one of these is remappable under `keymaps`, grouped by pane. See
`:help if-db-keymaps` for the full set.

## Completion

The plugin registers an `ifdb` source offering tables, columns and
keywords from the schema of the connection you are querying.

```lua
-- nvim-cmp
require("cmp").setup {
  sources = { { name = "ifdb" } },
}

-- blink.cmp
require("blink.cmp").setup {
  sources = {
    default = { "lsp", "path", "snippets", "buffer", "ifdb" },
    providers = {
      ifdb = { name = "ifdb", module = "blink_ifdb" },
    },
  },
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

  keymaps = {},       -- see :help if-db-keymaps
  highlights = {},    -- override any IfDb* group
}
```

Saved queries and history live under `stdpath("data")/if.db`.

## Highlights

Every group can be overridden through `highlights`, or defined before
`setup()`. Groups marked computed are derived from your colorscheme
rather than hardcoded.

```lua
highlights = {
  IfDbHeader = { bg = "#ff6600", fg = "#000000" },
  IfDbNull = { fg = "#555555", italic = true },
}
```

| Result | Default |
|---|---|
| `IfDbRowOdd` `IfDbRowEven` | computed from the `Normal` background |
| `IfDbHeader` | computed from the `Function` foreground |
| `IfDbSeparator` | `Comment` |
| `IfDbCellActive` | `CursorLine` |

| Value types | Default |
|---|---|
| `IfDbNull` | `Comment` |
| `IfDbNumber` | `Number` |
| `IfDbString` | `Normal` |
| `IfDbBoolean` | `Boolean` |
| `IfDbDateTime` | `Special` |
| `IfDbUuid` | `Constant` |
| `IfDbJson` | `Function` |

| Schema | Default |
|---|---|
| `IfDbTable` | `Type` |
| `IfDbKey` | `Keyword` |
| `IfDbPK` | `ErrorMsg`, bold |
| `IfDbFK` | `Function`, bold |

| History | Default |
|---|---|
| `IfDbHistoryVerb` | `@keyword.sql` |
| `IfDbHistoryTarget` | `@type.sql` |
| `IfDbHistoryColumn` | `@variable.member.sql` |
| `IfDbHistoryCount` | `@number.sql` |
| `IfDbHistoryHint*` | `@keyword.sql`, one group per clause |
| `IfDbHistoryTime` | `Comment` |
| `IfDbHistoryDuration` | `Number` |
| `IfDbHistoryRowOdd` `IfDbHistoryRowEven` | computed |

The shorthand borrows the colours tree-sitter gives SQL, so a verb, a
table and a column read the same in the history pane as they do in the
editor above it. Override any group to break that link.

The window, sidebar and icon groups are in `:help if-db-highlights`.

## Development

```sh
make test                                  # all specs
make test-file FILE=tests/core/schema_spec.lua
make lint                                  # stylua --check + selene
make format                                # stylua
```

## Credits

- [vim-dadbod-ui](https://github.com/kristijanhusak/vim-dadbod-ui), the
  classic DB UI for Vim and Neovim
- [nvim-dbee](https://github.com/kndndrj/nvim-dbee), a modern take on the
  same problem

if.db is the lightweight, self-contained corner of that space: no driver,
no daemon, just the CLI you already have.

## License

MIT. See [LICENSE](LICENSE).
