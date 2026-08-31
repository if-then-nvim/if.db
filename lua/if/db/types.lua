---@meta

---@alias IfDb.ExecutorBackend "cli"|"dadbod"

---@class IfDb.Config
---@field connections IfDb.Connection[]
---@field executor IfDb.ExecutorBackend Executor backend ("cli" = self-contained, "dadbod" = vim-dadbod)
---@field layout IfDb.LayoutConfig Pane proportions
---@field sidebar IfDb.SidebarConfig
---@field result IfDb.ResultConfig
---@field history IfDb.HistoryConfig
---@field keymaps IfDb.Keymaps
---@field highlights? table<string, table> Highlight group overrides (nvim_set_hl opts)

---@class IfDb.Connection
---@field name string Connection display name
---@field url string Database connection URL (supports env vars like $DATABASE_URL)

---@class IfDb.SidebarConfig
---@field show_system_schemas boolean Show system schemas (pg_catalog, information_schema)

---@class IfDb.ResultConfig
---@field max_width number Maximum grid width
---@field max_height number Maximum grid height
---@field show_line_number boolean Show line numbers in result grid

---@alias IfDb.HistoryField "icon"|"time"|"dbname"|"query"|"duration"

---@class IfDb.HistoryConfig
---@field max_entries number Maximum history entries (default 100)
---@field on_select "execute"|"load" Action when selecting history item
---@field persist boolean Whether to persist history to disk
---@field filter_by_connection boolean Filter history by current connection (default true)
---@field format? IfDb.HistoryField[] Fields to show and their order (nil = auto based on filter_by_connection)

---@class IfDb.Keymaps
---@field open string Keymap to open if.db
---@field execute string Keymap to execute query (Global)
---@field close string Keymap to close if.db (Global)
---@field sidebar IfDb.SidebarKeymaps
---@field history IfDb.HistoryKeymaps
---@field editor IfDb.EditorKeymaps
---@field result IfDb.ResultKeymaps

---@class IfDb.SidebarKeymaps
---@field toggle_expand string|string[] Toggle expand/collapse or open query
---@field refresh string Refresh sidebar
---@field rename string Rename saved query
---@field new_query string Create new query
---@field copy_name string Copy node name
---@field insert_template string Insert table query template
---@field delete string Delete saved query
---@field copy_query string Copy saved query content
---@field paste_query string Paste saved query
---@field to_editor string Move focus to editor
---@field to_history string Move focus to history
---@field toggle_types string Show or hide column types

---@class IfDb.HistoryKeymaps
---@field select string Select entry (load or execute)
---@field execute string Re-execute query
---@field copy string Copy query text
---@field delete string Delete entry
---@field clear string Clear all history
---@field to_sidebar string Move focus to sidebar
---@field to_result string Move focus to result

---@class IfDb.EditorKeymaps
---@field execute_insert string Execute query in insert mode
---@field execute_leader string Execute query with leader
---@field save string Save current query
---@field next_tab string Next query tab
---@field prev_tab string Previous query tab
---@field close_tab string Close current tab
---@field to_result string Move focus to result
---@field to_sidebar string Move focus to sidebar

---@class IfDb.ResultKeymaps
---@field yank_row string Yank current row as JSON
---@field yank_all string Yank all rows as JSON
---@field to_sidebar string Move focus to sidebar
---@field to_editor string Move focus to editor

---@alias IfDbConfig IfDb.Config
---@alias IfDbConnection IfDb.Connection
---@alias IfDbGridConfig IfDb.ResultConfig
---@alias IfDbHistoryConfig IfDb.HistoryConfig
---@alias IfDbHistoryEntry IfDb.HistoryEntry
---@alias IfDbKeymaps IfDb.Keymaps

---@class IfDb.Schema
---@field name string Schema name
---@field table_count number Number of tables in schema

---@class IfDb.Table
---@field name string Table name
---@field type "table"|"view" Table type

---@class IfDb.Column
---@field name string Column name
---@field data_type string SQL data type
---@field is_nullable boolean Whether column allows NULL
---@field is_primary boolean Whether column is primary key

---@alias IfDbSchema IfDb.Schema
---@alias IfDbTable IfDb.Table
---@alias IfDbColumn IfDb.Column

---@class IfDb.HistoryEntry
---@field query string SQL query text
---@field timestamp number Unix timestamp
---@field conn_name string Connection name
---@field duration_ms? number Execution time in milliseconds
---@field row_count? number Number of rows returned

---@class IfDb.QueryResult
---@field columns string[] Column names
---@field rows string[][] Row data (each row is array of cell values)
---@field row_count number Total number of rows
---@field raw string Raw query output

---@class IfDb.QueryTab
---@field buf number Buffer number
---@field name string Tab display name
---@field conn_name string Associated connection name
---@field modified boolean Whether buffer has unsaved changes
---@field is_saved boolean Whether query is saved to disk

---@alias IfDbQueryResult IfDb.QueryResult
---@alias QueryTab IfDb.QueryTab

---@alias IfDb.SidebarNodeType

---@class IfDb.SidebarNode
---@field type IfDb.SidebarNodeType Node type
---@field name string Display name
---@field expanded boolean Whether node is expanded
---@field depth number Indentation depth
---@field data_type? string Column data type (for column nodes)
---@field is_primary? boolean Is primary key (for column nodes)
---@field parent? string Parent connection name
---@field schema? string Schema name (for table nodes)
---@field action? string Action to perform on select
---@field query_path? string Path to saved query file
---@field tab_index? number Index in query_tabs array

---@alias SidebarNode IfDb.SidebarNode
---@alias SidebarNodeType IfDb.SidebarNodeType

---@alias IfDb.DatabaseType "postgres"|"mysql"|"sqlite"|"unknown"

---@class IfDb.LayoutConfig
---@field top_ratio number Top strip height as a fraction of the screen
---@field schema_width number Schema pane width as a fraction of the screen
---@field history_width number History pane width as a fraction of the screen
