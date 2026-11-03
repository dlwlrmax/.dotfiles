# Quickshell Todo Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a todo module to the Quickshell shell: bar icon with pending badge, popup panel, due dates with overdue colouring, a notification when a todo comes due, and marker dots on calendar days.

**Architecture:** Pure logic in `todo/TodoLogic.js` (node-tested). Persistence in a new `todos` table in `common/Db.qml`. State and the due-timer live in `providers/TodoData.qml` (instantiated in `DataProviders.qml`), so notifications fire with the panel closed. UI is `todo/Todo.qml` (bar widget) and `todo/TodoPanel.qml` (+ `TodoRow.qml`, `TodoAddBar.qml`) hosted by `PanelHost` in `shell.qml`. Calendar only receives `markedKeys` as data.

**Tech Stack:** Quickshell (QML, Qt 6), QtQuick.LocalStorage SQLite, `notify-send`, node for JS tests.

**Spec:** `docs/superpowers/specs/2026-11-03-todo-module-design.md`

Paths below are relative to `quickshell/.config/quickshell/` (written `QS/`) unless they start with `docs/`. Run git commands from `/home/kienct/.dotfiles`. Commit messages use the repo's `quickshell: ...` prefix and end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Global Constraints

- A date-only todo is due at 09:00 local time: `DEFAULT_DUE_MINUTES = 540`.
- Due-check timer: every 30 s, plus once at startup. Re-sort/overdue state also refreshes on that tick.
- Notification: `Quickshell.execDetached(["notify-send", "-a", "Todo", ...])`, fired exactly once per todo (`notified` flag).
- No title or due-date editing after creation (delete and re-add). No recurring, tags, sub-tasks, multiple lists.
- Never run `Db` tests against the live DB: use `XDG_DATA_HOME`/`XDG_STATE_HOME`/`XDG_CACHE_HOME` pointing to temp dirs (note at top of `common/Db.qml`).
- Calendar must not import `qs.todo`; it only receives `markedKeys`.
- Panel is a `Component` built only while open (`PanelHost`); width token `theme.panelWidthM`; no new theme tokens.
- Calendar day key = integer `yyyymmdd` (`CalendarLogic.js` `makeKey`/`keyOf`). Calendar todo dot colour: `theme.green`.
- Follow repo conventions: `property Theme theme: ThemeStore`, `qmldir` lines `Name 1.0 File.qml`, helper JS files start with `.pragma library`.

## Review Focus

1. Blank, multi-line or very long title: must not be added as empty; newlines collapse to spaces; capped at 200 chars (Task 1 `normalizeTitle` tests).
2. Title with `'`, `"`, `<b>` or a leading `-`: stored verbatim (parameterised SQL, Task 2 test) and shown as the notification summary without being parsed as an option (`--` before the title, Task 3).
3. Date-only todo for today added after 09:00: counts as due on the next tick and notifies immediately (Task 1 `dueNow` test).
4. Typed date edge cases: `31/02` rejected, `29/02` in a non-leap year resolves to the next leap year, `02/11` typed on 03/11 means next year, "Next week" across 31/12 (Task 1 tests).
5. Shell restart with several already-due, un-notified todos: each fires exactly once, none twice on later ticks (Task 3 manual check); list stays scrollable with hundreds of rows (Task 4 uses `ListView`).

---

### Task 1: TodoLogic.js with tests

**Files:**
- Create: `QS/todo/TodoLogic.js`
- Modify: `QS/tests/run.mjs` (add a `TodoLogic` section before the final `console.log(\`\n${passed} passed...` line)

**Interfaces:**
- Produces (all pure, `.pragma library`, no imports; `todo` = `{id, title, done: 0|1, due_key: number|null, due_minutes: number|null, notified: 0|1, created_at, done_at}`):
  - `DEFAULT_DUE_MINUTES` (= 540)
  - `dueMinutes(todo) -> number`
  - `dueStamp(todo) -> number` (`due_key * 1440 + dueMinutes(todo)`)
  - `isOverdue(todo, nowKey, nowMinutes) -> bool` (open, dated, due stamp strictly before now)
  - `dueNow(todos, nowKey, nowMinutes) -> todo[]` (open, dated, `notified == 0`, due stamp <= now)
  - `sortTodos(todos, nowKey, nowMinutes) -> todo[]` (new array: open before done; open: overdue first, then due stamp ascending, undated last, ties by `created_at`; done by `done_at` descending)
  - `markedKeys(todos) -> number[]` (sorted unique `due_key` of open dated todos)
  - `addDays(key, n) -> number`
  - `parseDue(text, todayKey) -> {key:number, minutes:number|null} | null`
  - `resolveDue(chip, typed, todayKey) -> {ok:bool, key:number|null, minutes:number|null}` (`chip` in `""|"today"|"tomorrow"|"week"`; non-empty `typed` overrides the chip; invalid typed -> `ok:false`)
  - `normalizeTitle(s) -> string`
  - `formatDue(todo, todayKey) -> string` (`""` if undated; with `todayKey != 0`: "Today"/"Tomorrow"/`dd/mm`, plus ` hh:mm` only when `due_minutes` set; with `todayKey == 0`: always `dd/mm hh:mm`, using 09:00 for date-only)

- [ ] **Step 1: Write the failing tests** in `QS/tests/run.mjs`, loading `todo/TodoLogic.js` with the existing `load(rel, names)` helper:

```js
const T = load("todo/TodoLogic.js", ["dueMinutes", "isOverdue", "dueNow", "sortTodos", "markedKeys",
    "addDays", "parseDue", "resolveDue", "normalizeTitle", "formatDue"])
const td = o => ({ id: 1, title: "t", done: 0, due_key: null, due_minutes: null, notified: 0,
                   created_at: 100, done_at: null, ...o })

console.log("TodoLogic")
test("date-only todo is due at 09:00", () => {
    assert.equal(T.dueMinutes(td({ due_key: 20261105 })), 540)
    assert.equal(T.dueMinutes(td({ due_key: 20261105, due_minutes: 600 })), 600)
})
test("isOverdue boundary and exclusions", () => {
    const t = td({ due_key: 20261105, due_minutes: 600 })
    assert.equal(T.isOverdue(t, 20261105, 600), false)
    assert.equal(T.isOverdue(t, 20261105, 601), true)
    assert.equal(T.isOverdue(td({ ...t, done: 1 }), 20261106, 0), false)
    assert.equal(T.isOverdue(td(), 20261106, 0), false)
})
test("dueNow: boundary, notified, done, late-added date-only", () => {
    const t = td({ id: 1, due_key: 20261105, due_minutes: 600 })
    assert.deepEqual(T.dueNow([t], 20261105, 599).map(x => x.id), [])
    assert.deepEqual(T.dueNow([t], 20261105, 600).map(x => x.id), [1])
    assert.deepEqual(T.dueNow([td({ ...t, notified: 1 })], 20261105, 700), [])
    assert.deepEqual(T.dueNow([td({ ...t, done: 1 })], 20261105, 700), [])
    const dateOnly = td({ id: 2, due_key: 20261105 })
    assert.deepEqual(T.dueNow([dateOnly], 20261105, 539), [])
    assert.deepEqual(T.dueNow([dateOnly], 20261105, 1020).map(x => x.id), [2])   // added at 17:00
})
test("sortTodos order", () => {
    const list = [
        td({ id: 1 }),                                                  // undated
        td({ id: 2, done: 1, done_at: 50 }),
        td({ id: 3, due_key: 20261105, due_minutes: 900 }),             // later today
        td({ id: 4, due_key: 20261101 }),                               // overdue
        td({ id: 5, done: 1, done_at: 80 }),
    ]
    assert.deepEqual(T.sortTodos(list, 20261105, 600).map(x => x.id), [4, 3, 1, 5, 2])
})
test("markedKeys: open dated only, unique, sorted", () => {
    const list = [td({ due_key: 20261105 }), td({ due_key: 20261105 }), td({ due_key: 20261101, done: 1 }),
                  td({ due_key: 20261103 }), td()]
    assert.deepEqual(T.markedKeys(list), [20261103, 20261105])
})
test("addDays crosses month/year and leap day", () => {
    assert.equal(T.addDays(20261231, 1), 20270101)
    assert.equal(T.addDays(20240228, 1), 20240229)
    assert.equal(T.addDays(20261105, 7), 20261112)
    assert.equal(T.addDays(20261101, -1), 20261031)
})
test("parseDue", () => {
    assert.deepEqual(T.parseDue("05/11", 20261103), { key: 20261105, minutes: null })
    assert.deepEqual(T.parseDue(" 05/11 14:30 ", 20261103), { key: 20261105, minutes: 870 })
    assert.deepEqual(T.parseDue("05/11 9:05", 20261103), { key: 20261105, minutes: 545 })
    assert.equal(T.parseDue("03/11", 20261103).key, 20261103)           // today counts
    assert.equal(T.parseDue("02/11", 20261103).key, 20271102)           // passed -> next year
    assert.equal(T.parseDue("29/02", 20261103).key, 20280229)           // next leap year
    assert.equal(T.parseDue("05/11/2027", 20261103).key, 20271105)
    for (const bad of ["", "abc", "31/02", "32/01", "05/13", "05/11 25:00", "05/11 10:60"])
        assert.equal(T.parseDue(bad, 20261103), null, bad)
})
test("resolveDue: chips, typed override, invalid", () => {
    const t = 20261231
    assert.deepEqual(T.resolveDue("", "", t), { ok: true, key: null, minutes: null })
    assert.deepEqual(T.resolveDue("today", "", t), { ok: true, key: 20261231, minutes: null })
    assert.deepEqual(T.resolveDue("tomorrow", "", t), { ok: true, key: 20270101, minutes: null })
    assert.deepEqual(T.resolveDue("week", "", t), { ok: true, key: 20270107, minutes: null })
    assert.deepEqual(T.resolveDue("today", "05/01 10:00", t), { ok: true, key: 20270105, minutes: 600 })
    assert.equal(T.resolveDue("", "garbage", t).ok, false)
})
test("normalizeTitle", () => {
    assert.equal(T.normalizeTitle("  hello   world \n"), "hello world")
    assert.equal(T.normalizeTitle("line1\nline2"), "line1 line2")
    assert.equal(T.normalizeTitle("   \n "), "")
    assert.equal(T.normalizeTitle("a".repeat(300)).length, 200)
})
test("formatDue", () => {
    assert.equal(T.formatDue(td(), 20261105), "")
    assert.equal(T.formatDue(td({ due_key: 20261105 }), 20261105), "Today")
    assert.equal(T.formatDue(td({ due_key: 20261105, due_minutes: 870 }), 20261105), "Today 14:30")
    assert.equal(T.formatDue(td({ due_key: 20261106 }), 20261105), "Tomorrow")
    assert.equal(T.formatDue(td({ due_key: 20261112 }), 20261105), "12/11")
    assert.equal(T.formatDue(td({ due_key: 20261105 }), 0), "05/11 09:00")
})
```

- [ ] **Step 2: Run to verify failure**

Run: `cd /home/kienct/.dotfiles/quickshell/.config/quickshell && node tests/run.mjs`
Expected: crash with `ENOENT ... todo/TodoLogic.js`.

- [ ] **Step 3: Implement `todo/TodoLogic.js`** with the signatures in Interfaces. Approach: `dueStamp` makes all comparisons single-number; `addDays` via `Date.UTC` day arithmetic (no DST issues); `parseDue` builds a candidate in `todayKey`'s year, validates by Date round-trip (rejects 31/02), rolls to the next year if before `todayKey`, and for 29/02 scans up to 8 years ahead; time must match `^\d{1,2}:\d{2}$` with hour < 24 and minute < 60; `normalizeTitle` collapses all whitespace runs (including newlines) to one space, trims, then `slice(0, 200)`.

- [ ] **Step 4: Run to verify pass**

Run: `cd /home/kienct/.dotfiles/quickshell/.config/quickshell && node tests/run.mjs`
Expected: all `TodoLogic` tests `ok`, final line `N passed, 0 failed`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add quickshell/.config/quickshell/todo/TodoLogic.js quickshell/.config/quickshell/tests/run.mjs
git commit -m "quickshell: add todo logic helpers with tests"
```

---

### Task 2: Db `todos` table and functions

**Files:**
- Modify: `QS/common/Db.qml` (header comment "five tables" -> "six tables, adds todos"; `open()` gets one more `CREATE TABLE IF NOT EXISTS`; new functions after the notification functions)
- Scratch (not committed): `$S/shell.qml` and symlink `$S/common` where `S=/tmp/claude-1000/-home-kienct--dotfiles/e1c31faf-2085-4686-9515-1db49ad5fc3b/scratchpad/dbtest`

**Interfaces:**
- Consumes: existing `Db.open()`, `Db._db`, `Db._now()` (unix seconds).
- Produces on `Db`:
  - `loadTodos() -> Array<todo>` (shape from Task 1; `done`/`notified` are 0|1; absent due fields are `null`; ordered by `id ASC`; `[]` on error)
  - `insertTodo(entry: {title: string, due_key?: number|null, due_minutes?: number|null}) -> int` (new id, `-1` on error; sets `created_at = _now()`)
  - `setTodoDone(id: int, done: bool)` (sets `done_at = _now()` or `NULL`)
  - `deleteTodo(id: int)`, `deleteDoneTodos()`, `markTodoNotified(id: int)`
  - All catch errors and `console.warn("Db: ...")`; all SQL uses `?` parameters.
- Table: exactly the `todos(...)` schema from the spec's Data model section.

- [ ] **Step 1: Write the failing test harness.** Create the scratch config:

```bash
S=/tmp/claude-1000/-home-kienct--dotfiles/e1c31faf-2085-4686-9515-1db49ad5fc3b/scratchpad/dbtest
mkdir -p $S/data $S/state $S/cache && ln -sfn /home/kienct/.dotfiles/quickshell/.config/quickshell/common $S/common
```

`$S/shell.qml`:

```qml
import Quickshell
import QtQuick
import qs.common

ShellRoot {
    Component.onCompleted: {
        var fails = 0
        function eq(name, a, b) {
            var ok = JSON.stringify(a) === JSON.stringify(b)
            if (!ok) fails++
            console.log((ok ? "PASS " : "FAIL ") + name + (ok ? "" : "  got " + JSON.stringify(a) + " want " + JSON.stringify(b)))
        }
        Db.open()
        var weird = "O'Brien \"x\" <b>-"
        var a = Db.insertTodo({ title: weird, due_key: 20261105, due_minutes: null })
        var b = Db.insertTodo({ title: "plain" })
        var rows = Db.loadTodos()
        eq("two rows", rows.length, 2)
        eq("title verbatim", rows[0].title, weird)
        eq("fields a", [rows[0].done, rows[0].due_key, rows[0].due_minutes, rows[0].notified, rows[0].done_at],
                       [0, 20261105, null, 0, null])
        eq("created_at set", rows[0].created_at > 0, true)
        eq("undated b", [rows[1].due_key, rows[1].due_minutes], [null, null])
        Db.setTodoDone(a, true)
        rows = Db.loadTodos()
        eq("done set", [rows[0].done, rows[0].done_at > 0], [1, true])
        Db.setTodoDone(a, false)
        eq("done cleared", [Db.loadTodos()[0].done, Db.loadTodos()[0].done_at], [0, null])
        Db.markTodoNotified(b)
        eq("notified", Db.loadTodos()[1].notified, 1)
        Db.setTodoDone(b, true)
        Db.deleteDoneTodos()
        eq("deleteDone keeps open", Db.loadTodos().map(r => r.id), [a])
        Db.deleteTodo(a)
        eq("deleteTodo", Db.loadTodos(), [])
        eq("notifications table untouched", Array.isArray(Db.loadNotifications()), true)
        console.log(fails === 0 ? "ALL PASS" : fails + " FAILED")
        Qt.quit()
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `S=<as above>; XDG_DATA_HOME=$S/data XDG_STATE_HOME=$S/state XDG_CACHE_HOME=$S/cache timeout 20 qs -p $S 2>&1 | grep -E "PASS|FAIL|ALL|TypeError|error" | head`
Expected: `TypeError: ... insertTodo is not a function` (or similar), no `ALL PASS`.

- [ ] **Step 3: Implement** the table and the six functions in `QS/common/Db.qml`, mirroring `insertNotification` / `loadHistory` style (`open()`, `_db.transaction` / `readTransaction`, `rs.insertId`), each body wrapped in `try/catch` with `console.warn`. `loadTodos` maps row nulls explicitly (`r.due_key ?? null`).

- [ ] **Step 4: Run to verify pass**

Run: same command as Step 2 (delete `$S/data` first for a clean DB: `rm -rf $S/data/* $S/state/* $S/cache/*`).
Expected: eleven `PASS` lines and `ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add quickshell/.config/quickshell/common/Db.qml
git commit -m "quickshell: add todos table and Db accessors"
```

---

### Task 3: TodoData provider (state, due-timer, notifications)

**Files:**
- Create: `QS/providers/TodoData.qml`
- Modify: `QS/providers/qmldir` (add `TodoData 1.0 TodoData.qml`), `QS/DataProviders.qml` (add `property alias todoData: todoData` and `TodoData { id: todoData; theme: root.theme }`)

**Interfaces:**
- Consumes: `Db.*` todo functions (Task 2); `TodoLogic.js` as `T` via `import "../todo/TodoLogic.js" as T`; `Cal.keyOf(date)` via `import "../common/CalendarLogic.js" as Cal`.
- Produces on `TodoData` (root `Item`, `property Theme theme: ThemeStore`):
  - `property var items` (sorted todos), `property int nowKey`, `property int nowMinutes`
  - `readonly property int pendingCount` (open todos), `overdueCount` (via `T.isOverdue`), `readonly property var markedKeys` (`T.markedKeys(items)`)
  - `function add(title: string, dueKey, dueMinutes)` (runs `T.normalizeTitle`, ignores blank; `dueKey`/`dueMinutes` may be `null`)
  - `function toggle(id: int)`, `function remove(id: int)`, `function clearDone()`, `function reload()`
  - `function tick()`: refresh `nowKey`/`nowMinutes` from `new Date()`, re-sort `items`, then for each `T.dueNow(...)` todo call `Quickshell.execDetached(["notify-send", "-a", "Todo", "-i", "checkbox-checked-symbolic", "--", todo.title, "Due " + T.formatDue(todo, 0)])` and `Db.markTodoNotified(todo.id)`, then `reload()` if anything fired.
  - `Timer { interval: 30000; repeat: true; running: true; triggeredOnStart: true; onTriggered: tick() }`

- [ ] **Step 1: Implement** the provider per Interfaces. Each mutator calls the `Db` function, then `reload()` (`items = T.sortTodos(Db.loadTodos(), nowKey, nowMinutes)`). Load once in `Component.onCompleted`.

- [ ] **Step 2: Verify it loads without errors**

Run: `qs log 2>&1 | tail -20` after saving (live reload).
Expected: no `ERROR`/`TypeError` lines mentioning `TodoData`; shell still shows bars.

- [ ] **Step 3: Verify due notification fires once (Review Focus 2, 5).** The `todos` table is new, so using the live DB here only touches rows this step creates. Insert three due rows, one with a leading `-` title:

```bash
DB="$HOME/.local/share/quickshell/QML/OfflineStorage/Databases/$(printf %s quickshell_state | md5sum | cut -d' ' -f1).sqlite"
sqlite3 "$DB" "INSERT INTO todos(title,due_key,created_at) VALUES ('-verify one',20200101,strftime('%s','now')),('verify two',20200101,strftime('%s','now')),('verify three',20200101,strftime('%s','now'));"
touch ~/.config/quickshell/shell.qml    # trigger live reload so the provider reloads and ticks
sleep 5; sqlite3 "$DB" "SELECT title,notified FROM todos WHERE title LIKE '%verify%';"
```

Expected: three rows all `notified = 1`; three toasts titled `-verify one`, `verify two`, `verify three` with body `Due 01/01 09:00`. Wait 70 s: no further toasts. Then clean up: `sqlite3 "$DB" "DELETE FROM todos WHERE title LIKE '%verify%';"`.

- [ ] **Step 4: Commit**

```bash
git add quickshell/.config/quickshell/providers/TodoData.qml quickshell/.config/quickshell/providers/qmldir quickshell/.config/quickshell/DataProviders.qml
git commit -m "quickshell: add todo data provider with due notifications"
```

---

### Task 4: Bar widget, panel list, wiring and IPC

**Files:**
- Create: `QS/todo/qmldir`, `QS/todo/Todo.qml`, `QS/todo/TodoPanel.qml`, `QS/todo/TodoRow.qml`
- Modify: `QS/common/Glyphs.qml` (add `readonly property string todo: ""`), `QS/Bar.qml` (import `qs.todo`; `property var todoDataSource: null`; widget after the `Weather` block, before `Volume`), `QS/shell.qml` (import `qs.todo`; add `"todo"` to `panelNames`; `todoDataSource: dp.todoData` in the `Bar`; a `PanelHost` named `"todo"`, `placement: "widget"`; a `todo` `IpcHandler` shaped like the existing `power` one), `QS/common/Panels.qml` (add `todo` to the panel-name comment)

**Interfaces:**
- Consumes: `TodoData` members from Task 3; `T.formatDue`, `T.isOverdue`; `Badge`, `PanelHeader`, `PanelBackground`, `IconButton`, `BarTooltip`, `Glyphs`.
- Produces:
  - `qmldir`: `module qs.todo`, `Todo 1.0 Todo.qml`, `TodoPanel 1.0 TodoPanel.qml`, `TodoRow 1.0 TodoRow.qml`, plus `TodoAddBar` line added in Task 5.
  - `Todo.qml`: `Item`, `property Theme theme: ThemeStore`, `property var dataSource: null`, `signal togglePanel()`. Shows `Glyphs.todo` plus a `Badge` of `dataSource.pendingCount` (hidden at 0; `clr` = `theme.red` when `overdueCount > 0`, else `theme.subtext0`); `BarTooltip` text `"<N> pending, <M> overdue"`; click emits `togglePanel()`. Wired in `Bar.qml` as `onTogglePanel: bar.togglePanel("todo", bar.centerOf(todoWidget))`.
  - `TodoRow.qml`: `required property var todo`, `property Theme theme`, `property int nowKey`, `property int nowMinutes`, `signal toggled()`, `signal removed()`. Checkbox (square `Rectangle` with `Glyphs.check` when done), title (strike-through + dimmed when done, elided), due label via `T.formatDue(todo, nowKey)`; overdue -> `theme.red` text, due today -> `theme.highlight`; delete `IconButton` (`Glyphs.close`) visible on hover.
  - `TodoPanel.qml`: `Item`, `property Theme theme: ThemeStore`, `property bool active: false`, `property var dataSource: null`, `signal close()`; `implicitWidth: theme.panelWidthM`; `implicitHeight` grows with the list up to the `maxHeight` binding copied from `weather/WeatherPanel.qml`, minimum 220; `focus: true`, `Keys.onEscapePressed: root.close()`. Layout: `PanelBackground`, `PanelHeader` titled "Todo" with a `Badge` of `pendingCount` and an `IconButton` (`Glyphs.trash`) calling `dataSource.clearDone()` (disabled when no done items), a `ListView` of `TodoRow` over `dataSource.items` (empty-state `Text` "Nothing to do"), and a placeholder `Item { id: addSlot }` at the bottom that Task 5 replaces.
  - IPC: `qs ipc call todo toggle` / `close` using `Panels.toggle("todo", shell.screenNameOfFocus(), 0)`.

- [ ] **Step 1: Implement** the files per Interfaces; follow `weather/Weather.qml` for the widget skeleton and `weather/WeatherPanel.qml` for panel sizing.

- [ ] **Step 2: Verify no load errors**

Run: `qs log 2>&1 | tail -20`
Expected: no `ERROR` mentioning `todo`; every screen's bar shows the todo icon next to weather.

- [ ] **Step 3: Verify behaviour manually.** Insert two rows with sqlite3 (one overdue `due_key=20200101`, one undated, both `notified=1` so no toast), reload, then:
  - `qs ipc call todo toggle` opens the panel under the focused monitor; `qs ipc call panel list` includes `todo`.
  - Overdue row is red, undated row has no due label; badge shows 2, red tint.
  - Click checkbox: row strikes through, moves to bottom, badge shows 1; click again restores it.
  - Delete button removes the row; "clear done" removes done rows only.
  - Esc closes; clicking the bar icon again also closes.
  Clean up the test rows afterwards (`DELETE FROM todos WHERE title LIKE 'verify%'`; name them `verify ...`).

- [ ] **Step 4: Commit**

```bash
git add quickshell/.config/quickshell/todo quickshell/.config/quickshell/common/Glyphs.qml quickshell/.config/quickshell/common/Panels.qml quickshell/.config/quickshell/Bar.qml quickshell/.config/quickshell/shell.qml
git commit -m "quickshell: add todo bar widget and panel"
```

---

### Task 5: Add bar (title, due chips, typed due)

**Files:**
- Create: `QS/todo/TodoAddBar.qml`
- Modify: `QS/todo/qmldir` (add `TodoAddBar 1.0 TodoAddBar.qml`), `QS/todo/TodoPanel.qml` (replace the `addSlot` placeholder)

**Interfaces:**
- Consumes: `T.resolveDue(chip, typed, todayKey)`, `T.normalizeTitle`; `TodoData.add(title, dueKey, dueMinutes)`.
- Produces: `TodoAddBar.qml`: `Item`, `property Theme theme: ThemeStore`, `property int todayKey`, `signal submitted(string title, var dueKey, var dueMinutes)`, `function focusTitle()`. Contents: `TextField` for the title (Enter submits), three chip toggles "Today" / "Tomorrow" / "Next week" (mutually exclusive; clicking the active chip clears it), and a small `TextField` with placeholder `dd/mm [hh:mm]`. Submit: `r = T.resolveDue(chip, typed, todayKey)`; if `!r.ok` tint the typed field `theme.red` and do nothing; if `T.normalizeTitle(title) === ""` do nothing; otherwise emit `submitted(...)` and reset all inputs. `TodoPanel` connects `onSubmitted` to `dataSource.add(...)` and calls `focusTitle()` from `onActiveChanged` when `active` becomes true; `todayKey` is `dataSource.nowKey`.

- [ ] **Step 1: Implement** per Interfaces. No new logic beyond calling `TodoLogic`; the chip -> date rules are already covered by Task 1 tests.

- [ ] **Step 2: Verify manually** (rows created here are named `verify ...`, delete them after):
  - Panel opens with the title field focused; Enter on empty or whitespace-only title adds nothing.
  - `verify a` + Enter: adds an undated row.
  - `verify b` + chip "Today": row shows "Today"; if the time is past 09:00 a toast appears within 30 s (Review Focus 3).
  - `verify c` + typed `31/02`: field turns red, nothing added. Typed `05/01 10:00` adds a row labelled `05/01 10:00` (next January when run in November).
  - `verify d` + chip "Next week": row shows a `dd/mm` label 7 days ahead.
  - A title of 300 characters is stored cut to 200 and elided in the row.

- [ ] **Step 3: Commit**

```bash
git add quickshell/.config/quickshell/todo
git commit -m "quickshell: add todo add-bar with due chips"
```

---

### Task 6: Calendar markers

**Files:**
- Modify: `QS/calendar/CalendarPanel.qml`, `QS/calendar/MonthView.qml`, `QS/calendar/DayCell.qml`, `QS/shell.qml` (the `hCalendar` PanelHost)

**Interfaces:**
- Consumes: `TodoData.markedKeys` (Task 3).
- Produces:
  - `CalendarPanel`: `property var markedKeys: []` and `readonly property var markedSet` (object `{key: true}` rebuilt only when `markedKeys` changes). Passed to both `MonthView` instances (overview delegate and zoomed Loader) as `markedSet: root.markedSet`.
  - `MonthView`: `property var markedSet: ({})`.
  - `DayCell`: `readonly property bool hasTodo: !other && view.markedSet[key] === true`. Small view: a 4 px dot (`theme.green`) at the bottom centre of the day badge. Big view: a 5 px dot (`theme.green`) next to the day number. Must not collide with the holiday dot (top-right of the badge) or hide the number.
  - `shell.qml`: `CalendarPanel { anchors.fill: parent; markedKeys: dp.todoData.markedKeys; onClose: Panels.close() }`.

- [ ] **Step 1: Implement** per Interfaces.

- [ ] **Step 2: Verify manually** (test rows named `verify ...`, deleted afterwards):
  - Add `verify cal` due `05/11` (current month): open the calendar, both the year overview and a zoomed month show a green dot on the 5th and none elsewhere.
  - Tick the todo done in the todo panel: the dot disappears without reopening the calendar. Delete it: same.
  - Two open todos on one day show a single dot. A holiday day with a todo shows both dots without overlap.
  - Calendar still works with `todoData` absent: `qs log` clean on reload.

- [ ] **Step 3: Run the whole test suite and check logs**

Run: `cd /home/kienct/.dotfiles/quickshell/.config/quickshell && tests/run.sh && qs log 2>&1 | tail -20`
Expected: `0 failed`, palette self-test passes, no QML errors.

- [ ] **Step 4: Commit**

```bash
git add quickshell/.config/quickshell/calendar quickshell/.config/quickshell/shell.qml
git commit -m "quickshell: mark days with open todos in the calendar"
```
