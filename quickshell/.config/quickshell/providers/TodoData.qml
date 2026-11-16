// TodoData
// Todo list state from the Db todos table, plus the due check: every 30 s (and
// once at startup) open todos that reached their due time are announced with one
// notification each and flagged notified so they never fire again.
import Quickshell
import QtQuick
import qs.common
import "../todo/TodoLogic.js" as T
import "../common/CalendarLogic.js" as Cal

Item {
    id: root
    property Theme theme: ThemeStore

    // Sorted todos (see TodoLogic.sortTodos); refreshed by reload()/tick().
    property var items: []
    // Today as yyyymmdd and minutes after midnight, refreshed by tick().
    property int nowKey: Cal.keyOf(new Date())
    property int nowMinutes: new Date().getHours() * 60 + new Date().getMinutes()

    readonly property int pendingCount: {
        var n = 0
        for (var i = 0; i < items.length; i++) if (!items[i].done) n++
        return n
    }
    readonly property int overdueCount: {
        var n = 0
        for (var i = 0; i < items.length; i++) if (T.isOverdue(items[i], nowKey, nowMinutes)) n++
        return n
    }
    // Open dated todos' day keys, for calendar markers.
    readonly property var markedKeys: T.markedKeys(items)

    function _refreshNow() {
        var d = new Date()
        nowKey = Cal.keyOf(d)
        nowMinutes = d.getHours() * 60 + d.getMinutes()
    }

    // Assign only when the sorted list really changed: reassigning an equal array
    // resets the panel ListView's scroll position and re-fires markedKeys.
    function _setItems(sorted) {
        if (JSON.stringify(sorted) !== JSON.stringify(items)) items = sorted
    }

    function reload() {
        _setItems(T.sortTodos(Db.loadTodos(), nowKey, nowMinutes))
    }

    // larkId: record id of the Lark task / order this todo mirrors (optional).
    function add(title, content, dueKey, dueMinutes, larkId, larkCoding) {
        var t = T.normalizeTitle(title === null || title === undefined ? "" : title)
        if (t === "") return
        Db.insertTodo({
            title: t,
            content: T.normalizeContent(content),
            due_key: dueKey === undefined ? null : dueKey,
            due_minutes: dueMinutes === undefined ? null : dueMinutes,
            lark_id: larkId || null,
            lark_coding: larkCoding ? 1 : 0
        })
        reload()
    }

    // The user ticked a todo that mirrors a Lark record (not emitted when the Lark
    // sync ticks it, nor on un-ticking). LarkData pushes the change to Lark.
    signal larkTicked(string larkId, string title)

    function toggle(id) {
        for (var i = 0; i < items.length; i++) {
            if (items[i].id === id) {
                var nowDone = !items[i].done
                Db.setTodoDone(id, nowDone)
                if (nowDone && items[i].lark_id) larkTicked(items[i].lark_id, items[i].title)
                break
            }
        }
        reload()
    }

    // Mark done without toggling (the Lark sync ticks todos finished on Lark).
    function setDone(id) {
        Db.setTodoDone(id, true)
        reload()
    }

    // The Lark record behind these todos is (no longer) "Đang code".
    function setLarkCoding(larkId, coding) {
        if (!larkId) return
        Db.setTodoLarkCoding(larkId, coding)
        reload()
    }

    // dueKey null = no deadline; dueMinutes null = date only.
    function setDue(id, dueKey, dueMinutes) {
        var k = dueKey ?? null, m = k === null ? null : (dueMinutes ?? null)
        // Unchanged: keep it as it is (saving would re-arm the due notification).
        for (var i = 0; i < items.length; i++)
            if (items[i].id === id && items[i].due_key === k && items[i].due_minutes === m) return
        Db.setTodoDue(id, k, m)
        reload()
    }

    function rename(id, title) {
        var t = T.normalizeTitle(title)
        if (t === "") return
        Db.setTodoTitle(id, t)
        reload()
    }

    function remove(id) {
        Db.deleteTodo(id)
        reload()
    }

    // Completed todos stay in the list (struck through) for a week, then are removed
    // by the periodic tick: once per calendar day (the first tick of a run counts as a
    // new day, so a machine that is off overnight still gets cleaned up).
    readonly property int doneRetentionDays: 7
    property int _lastPurgeKey: 0

    function _purgeOldDone() {
        if (nowKey === _lastPurgeKey) return
        _lastPurgeKey = nowKey
        Db.purgeDoneTodos(doneRetentionDays)
    }

    function tick() {
        _refreshNow()
        _purgeOldDone()
        // Load fresh rows so external edits are seen and ordering follows the clock.
        var rows = Db.loadTodos()
        var due = T.dueNow(rows, nowKey, nowMinutes)
        for (var i = 0; i < due.length; i++) {
            var todo = due[i]
            Quickshell.execDetached(["notify-send", "-a", "Todo", "-i", "checkbox-checked-symbolic",
                "--", todo.title, "Due " + T.formatDue(todo, 0)])
            Db.markTodoNotified(todo.id)
        }
        if (due.length > 0) reload()
        else _setItems(T.sortTodos(rows, nowKey, nowMinutes))
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.tick()
    }

    Component.onCompleted: reload()
}
