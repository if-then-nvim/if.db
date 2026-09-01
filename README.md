# if.db

A database client for Neovim. It shells out to the database's own CLI, so
there is no driver to install and nothing to compile.

PostgreSQL, MySQL, MariaDB and SQLite.

![if.db](./screenshots/hero.webp)

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
shorthand needs to stay on one line, and never over half the screen.

## Requirements

- Neovim >= 0.10
- The CLI for whichever database you connect to: `psql`, `mysql` or
  `sqlite3`
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)

Optional: [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) for
async execution, [vim-dadbod](https://github.com/tpope/vim-dadbod) if you
prefer `executor = "dadbod"` over the CLI.

## Install

```lua
{
  "if-then-nvim/if.db",
  cmd = "IfDb",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {
    connections = {
      { name = "local", url = "postgres://localhost/mydb" },
      { name = "prod", url = "$DATABASE_URL" },
    },
  },
}
```

Connection URLs take the usual shape, and `$VAR` or `${VAR}` is expanded:

```
postgres://user:password@host:port/database
mysql://user:password@host:port/database
mariadb://user:password@host:port/database
sqlite:///path/to/database.db
```

Open it with `:IfDb`, close it with `:IfDbClose`.

## History

The history pane is written in a shorthand rather than echoing the SQL,
which is already on screen in the editor beside it:

```
10:35  SEL stories 󰈲 karma 󰕤 users 󰒼   53ms
10:35  SEL user_detail 󰈲 id 󰆐 20        31ms
10:34  DEL comments 󰈲 story_id         50ms
10:33  SEL users 󰒽                     60ms
10:33  SEL stories 󰒠                   99ms
```

| Marker | Clause |
|---|---|
| `󰈲 column` | `WHERE`, with the column it filters on |
| `󰕤 name` | `JOIN name` |
| `󰒽` `󰒼` | `ORDER BY`, ascending or descending |
| `󰒠` | `GROUP BY` |
| `󰆐 n` | `LIMIT n` |

A clause shows its value when the value tells you which query this was:
the column a WHERE filters on, the table a JOIN reaches for, the row
count a LIMIT stops at. Sort and group columns are left off, because
knowing a query was sorted rarely helps you find it and the names are
long.

Markers are never half-drawn. When the pane is too narrow, a table or
column name truncates with an ellipsis, and a marker that will not fit
whole is dropped instead of leaving a stub.

The timing is laid out from the right edge inward, so a narrow pane
truncates the query text rather than dropping the number you wanted.

## Keymaps

Anywhere: `q` closes, `?` shows the keymaps for the pane you are in.

| Sidebar | |
|---|---|
| `<CR>` `o` | Expand or collapse, or open a query |
| `n` | New query |
| `r` | Rename query |
| `d` | Delete query |
| `y` `c` `p` | Copy name, copy query, paste query |
| `S` `i` | Insert a SELECT or INSERT template |
| `t` | Show or hide column types |
| `R` | Refresh the schema |
| `<Tab>` `<S-Tab>` | Editor, history |

| Editor | |
|---|---|
| `<CR>` | Execute |
| `<C-CR>` | Execute from insert mode |
| `<C-s>` | Save |
| `gt` `gT` | Next, previous query |
| `<Leader>w` | Close query |
| `<Tab>` `<S-Tab>` | Result, sidebar |

| History | |
|---|---|
| `<CR>` | Load or execute, per `history.on_select` |
| `R` | Execute again |
| `y` `d` `C` | Copy, delete, clear all |
| `<Tab>` `<S-Tab>` | Sidebar, result |

| Result | |
|---|---|
| `y` `Y` | Yank the row, or every row, as JSON |
| `<Tab>` `<S-Tab>` | Sidebar, editor |

## Completion

The plugin registers an `ifdb` source that offers tables, columns and
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
    max_width = 120,
    max_height = 20,
    show_line_number = true,
  },

  history = {
    max_entries = 100,
    on_select = "execute",     -- or "load"
    persist = true,
    filter_by_connection = true,
  },

  highlights = {},   -- override any IfDb* group
}
```

Keymaps live under `keymaps`, grouped by pane: `keymaps.sidebar`,
`keymaps.editor`, `keymaps.history`, `keymaps.result`, plus the global
`open`, `execute` and `close`. See `:help if-db-config-keymaps` for the
full set.

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
| `IfDbRowOdd` `IfDbRowEven` | computed from `CursorLine` |
| `IfDbHeader` | computed from the `Function` foreground |
| `IfDbSeparator` | `Comment` |
| `IfDbCellActive` | `CursorLine` |

| Windows | Default |
|---|---|
| `IfDbFloat` | `NormalFloat` |
| `IfDbBorder` | `WinSeparator` |
| `IfDbTitle` | `Title` |

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

| Sidebar | Default |
|---|---|
| `IfDbIconDb` | `Number`, for an unrecognised type |
| `IfDbIconPostgres` … `IfDbIconMongodb` | brand colours, bold |
| `IfDbSidebarIcon*` | per node kind |
| `IfDbSidebarText` `IfDbSidebarTextActive` | `Normal`, `String` |
| `IfDbSidebarType` | `Comment` |

| History | Default |
|---|---|
| `IfDbHistoryHeader` | `Title`, bold |
| `IfDbHistoryRowOdd` `IfDbHistoryRowEven` | computed |
| `IfDbHistoryTime` | `Comment` |
| `IfDbHistoryDuration` | `Number` |
| `IfDbHistoryVerb` | `@keyword.sql` |
| `IfDbHistoryTarget` | `@type.sql` |
| `IfDbHistoryColumn` | `@variable.member.sql` |
| `IfDbHistoryCount` | `@number.sql` |
| `IfDbHistoryHint*` | `@keyword.sql`, one group per clause |

The shorthand borrows the colours tree-sitter gives SQL, so a verb, a
table and a column read the same in the history pane as they do in the
editor above it. Override any group to break that link.

## Credits

- [vim-dadbod-ui](https://github.com/kristijanhusak/vim-dadbod-ui), the
  classic DB UI for Vim and Neovim
- [nvim-dbee](https://github.com/kndndrj/nvim-dbee), a modern take on the
  same problem

if.db is the lightweight, self-contained corner of that space: no driver,
no daemon, just the CLI you already have.

## License

MIT. See [LICENSE](LICENSE).
