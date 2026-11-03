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

    function add(title, dueKey, dueMinutes) {
        var t = T.normalizeTitle(title === null || title === undefined ? "" : title)
        if (t === "") return
        Db.insertTodo({
            title: t,
            due_key: dueKey === undefined ? null : dueKey,
            due_minutes: dueMinutes === undefined ? null : dueMinutes
        })
        reload()
    }

    function toggle(id) {
        for (var i = 0; i < items.length; i++) {
            if (items[i].id === id) {
                Db.setTodoDone(id, !items[i].done)
                break
            }
        }
        reload()
    }

    function remove(id) {
        Db.deleteTodo(id)
        reload()
    }

    function clearDone() {
        Db.deleteDoneTodos()
        reload()
    }

    function tick() {
        _refreshNow()
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
