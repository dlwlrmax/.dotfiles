# Quickshell Todo Module — Design

Date: 2026-11-03
Scope: `quickshell/.config/quickshell/`

## Goal

Personal todo list inside the Quickshell shell: quick add from the bar, optional due
date/time, overdue highlighting, a desktop notification when a todo comes due, and a
marker dot on calendar days that have open todos.

Out of scope (YAGNI): recurring todos, tags, sub-tasks, multiple lists, sync, editing
a todo's title after creation (delete and re-add).

## Decisions made with the user

- Scope level C: checklist + due date/time + notification + calendar integration.
- UI: its own panel plus a bar icon with a pending-count badge. Calendar only gains
  a marker dot; no todo list inside `CalendarPanel`.
- State and due-timer live in a provider (`providers/TodoData.qml`), not in the panel,
  because panels are destroyed when closed (see `PanelHost.qml`) and notifications
  must fire while the panel is closed.

## Data model

New table in `common/Db.qml`, created in `open()` with `CREATE TABLE IF NOT EXISTS`:

```
todos(
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  title       TEXT NOT NULL,
  done        INTEGER DEFAULT 0,
  due_key     INTEGER,            -- yyyymmdd (CalendarLogic.makeKey), NULL = no due date
  due_minutes INTEGER,            -- minutes after midnight, NULL = date only
  notified    INTEGER DEFAULT 0,
  created_at  INTEGER,            -- unix seconds
  done_at     INTEGER             -- unix seconds, NULL while open
)
```

New `Db` functions: `loadTodos()`, `insertTodo(entry) -> id`, `setTodoDone(id, done)`,
`deleteTodo(id)`, `deleteDoneTodos()`, `markTodoNotified(id)`. Same style as the
notification functions (transaction + `executeSql`). A DB error is caught and logged
with `console.warn`; callers get an empty list or no-op, never an exception into the bar.

A date-only todo is treated as due at 09:00 local time (`DEFAULT_DUE_MINUTES = 540`).

## Components

### `todo/TodoLogic.js` (pure JS, unit-tested)

Imports nothing from QML. Reuses key helpers by taking keys as plain numbers.

- `dueMinutes(todo)` → `todo.due_minutes ?? 540` for todos with a due date.
- `isOverdue(todo, nowKey, nowMinutes)` → open, has due date, and due moment is before now.
- `dueNow(todos, nowKey, nowMinutes)` → open, `notified == 0`, due moment ≤ now.
- `sortTodos(todos, nowKey, nowMinutes)` → open before done; among open: overdue first,
  then by due moment ascending, undated last, then by `created_at`; done items by
  `done_at` descending.
- `markedKeys(todos)` → sorted unique `due_key` values of open todos (for calendar dots).
- `parseDue(text, todayKey)` → `{ key, minutes } | null` for `dd/mm`, `dd/mm/yyyy`,
  each optionally followed by ` hh:mm`. Year omitted → nearest future occurrence
  (today counts). Invalid date (e.g. 31/02) → `null`.
- Chip helpers: `todayKey`, `tomorrowKey`, `nextWeekKey` (today + 7 days), computed by
  the caller from `CalendarLogic.js` day arithmetic and passed in.

Tests added to `tests/run.mjs` in the existing style.

### `providers/TodoData.qml`

Instantiated in `DataProviders.qml` next to the other providers; registered in
`providers/qmldir`.

- Properties: `items` (sorted array, shape of table row), `pendingCount`,
  `overdueCount`, `markedKeys`.
- Functions: `add(title, dueKey, dueMinutes)`, `toggle(id)`, `remove(id)`, `clearDone()`.
  Each writes through `Db`, then reloads `items` (list is small; no incremental sync).
- `Timer` every 30 s plus once at startup: runs `dueNow`, and for each result calls
  `Quickshell.execDetached(["notify-send", "-a", "Todo", "-i", "checkbox-checked-symbolic", title, "Due 05/11 09:00"])`
  then `Db.markTodoNotified(id)`. Notifications go through the shell's own
  `NotifData`, so they appear in the notification history like any other.
- A todo's due date cannot be edited after creation, so there is no `notified` reset
  path; deleting and re-adding creates a fresh row.
- Also re-sorts on a minute tick so overdue state updates without user action.

### `todo/Todo.qml` (bar widget)

Icon (glyph from `common/Glyphs.qml`) with a `Badge` showing `pendingCount` (hidden at
0, red tint when `overdueCount > 0`). Emits `togglePanel(centerX)`. Placed in `Bar.qml`
in the status `Capsule` next to the weather/audio group; wired the same way as other
widgets: `onTogglePanel: bar.togglePanel("todo", bar.centerOf(this))`.

### `todo/TodoPanel.qml`, `todo/TodoRow.qml`

Panel uses `PanelBackground`, `PanelHeader` ("Todo", pending count, "Clear done"
`IconButton`), a scrollable list of `TodoRow`, and an add bar at the bottom:

- Text field: title. Enter adds.
- Due chips: Today, Tomorrow, Next week, plus a small field for typed `dd/mm [hh:mm]`
  (parsed by `parseDue`; invalid input tints the field red and does not add).
- `TodoRow`: checkbox (toggle), title (struck through when done), due label,
  delete button on hover. Overdue → red text. Due today → highlight colour.
- Escape closes (`onClose`), as in other panels. Width: the same width token the
  weather/volume panels use from `Theme.qml`; height capped to 90 % of screen like
  `CalendarPanel`.
- Uses theme colours and spring animations already used elsewhere; no new theme tokens.

### Calendar integration (minimal)

- `CalendarPanel` gets `property var markedKeys: []`, passes it to `MonthView`,
  which passes it to `DayCell`.
- `DayCell`: `readonly property bool hasTodo` = key in `markedKeys` (set lookup built
  once per change in `CalendarPanel`). Small view: 4 px dot at the bottom of the badge.
  Big view: small dot next to the day number. Colour: `theme.green`, distinct from the
  holiday dot (`red`/`sapphire`).
- `shell.qml` binds `markedKeys: dp.todo.markedKeys` when creating `CalendarPanel`.
  Calendar does not import `qs.todo`; it only receives data.

### Wiring and IPC

- `shell.qml`: `import qs.todo`; `PanelHost { name: "todo"; placement: "widget"; panel: TodoPanel }`;
  add `"todo"` to `panelNames` (line 77 area).
- `common/Panels.qml`: add `todo` to the panel-name comment.
- IPC: `IpcHandler { target: "todo"; toggle(); close() }`, same shape as `power` /
  `launcher`, so a Hyprland keybind can open it with `qs ipc call todo toggle`.

## Error handling

- DB failure on load: empty list, `console.warn`, bar widget shows no badge.
- DB failure on write: `console.warn`; list reloads from the DB so UI shows truth.
- `notify-send` missing: already a hard dependency in `deps/deps.list`; no extra handling.
- Screen unplugged while panel open: handled by the existing `onScreensChanged` in `shell.qml`.
- Shell restarts: due todos with `notified = 0` fire on the first timer tick; a todo
  already notified never fires again.

## Testing

- `TodoLogic.js`: unit tests in `tests/run.mjs` covering sort order, overdue boundary
  (exactly due minute), date-only default 09:00, `parseDue` (valid, year rollover,
  invalid dates, with/without time), `markedKeys` ignoring done todos, `dueNow`
  ignoring notified todos.
- `Db` todo functions: manual check against an isolated DB using
  `XDG_DATA_HOME/XDG_STATE_HOME/XDG_CACHE_HOME` pointing to temp dirs, per the note at
  the top of `common/Db.qml`. Never the live DB.
- Manual in the running shell: add/toggle/delete, overdue colour, notification fires
  once, badge count, calendar dot appears/disappears, `qs ipc call todo toggle`.
- Config reload (`qs`) must show no QML errors; `Quickshell.onReloadFailed` already
  surfaces them.

## File summary

New: `todo/{qmldir,Todo.qml,TodoPanel.qml,TodoRow.qml,TodoLogic.js}`,
`providers/TodoData.qml`.
Modified: `common/Db.qml`, `common/Panels.qml` (comment), `providers/qmldir`,
`DataProviders.qml`, `Bar.qml`, `shell.qml`, `calendar/{CalendarPanel,MonthView,DayCell}.qml`,
`tests/run.mjs`.
