// LarkData
// Lark Base state for the todo panel's "create a Lark task" flow: the open orders,
// the BU / Loại dự án choices, record creation and the OpenCode review of a task's
// text. Also the sync the other way: every 15 minutes (and on sync()) tasks / orders
// newly assigned to the user become local todos (a task and an order with the same
// title share one "Task/Order" todo), todos whose Lark record got finished are ticked
// and todos whose Lark record was deleted are removed.
// Ticking such a todo in the panel moves a "Đang code" record to "Chờ nghiệm thu", 100 %. All network work is done by scripts/lark-task.sh and scripts/lark-review.sh
// (which own the credentials); this only runs them and parses their one-line JSON.
import Quickshell
import Quickshell.Io
import QtQuick
import qs.common
import "../todo/LarkLogic.js" as L

Item {
    id: root
    property Theme theme: ThemeStore
    // TodoData: a created Lark task is mirrored as a local todo from here, so it
    // still happens when the panel was closed while the request was running.
    property var todoData: null

    // [{id, title, bu, project, status}], newest first.
    property var orders: []
    property var buOptions: []
    property var projectOptions: []
    // loading: orders / options are being fetched. busy: a create call is running.
    property bool loading: false
    property bool busy: false
    property string error: ""
    // false once a script reported that todo/.env is missing: no polling, no Lark UI.
    property bool configured: true
    // The panel's Lark picker is showing (it displays `error` itself). While it is
    // not, a failed create is reported with a notification instead.
    property bool watched: false

    // OpenCode review of the text about to be sent: {title, content} once done.
    property bool reviewing: false
    property var review: null
    property string reviewError: ""

    // Order of the current / last attempt. After a failure the same order is reused
    // by retry(), so an order that was just created is never created twice.
    property string lastOrderId: ""
    // The task being created: {title, content, dateKey, dueKey, dueMinutes}.
    property var _task: null
    // lastOrderId was created by this attempt: its task is the one the Base's own
    // automation adds for a new order (see lark-task.sh create-task --adopt).
    property bool _adopt: false
    // Orders created from here whose task has not been created yet (id -> true).
    property var _newOrders: ({})

    // Lark -> todo sync.
    property bool syncing: false
    property string syncError: ""
    // Unix ms of the last successful sync, 0 = never in this run.
    property double lastSyncAt: 0
    readonly property int syncIntervalMs: 15 * 60 * 1000

    signal orderCreated(string id, string title, string bu, string project)
    signal taskCreated(string url)
    signal failed(string message)

    readonly property string _taskScript: theme.scriptDir + "/lark-task.sh"
    readonly property string _reviewScript: theme.scriptDir + "/lark-review.sh"

    function _fail(message) {
        if (message === "Lark not configured") configured = false
        error = message
        failed(message)
    }

    // A create call failed. With the picker gone nobody would see `error`.
    function _createFailed(message) {
        busy = false
        _fail(message)
        if (!watched)
            Quickshell.execDetached(["notify-send", "-a", "Todo", "-u", "critical", "-i", "dialog-warning-symbolic",
                "--", "Lark task not created", (_task ? _task.title + "\n" : "") + message])
    }

    // One JSON object per run; anything else counts as a failure.
    function _parse(text) {
        try {
            var d = JSON.parse(String(text).trim())
            if (d && typeof d === "object") return d
        } catch (e) {}
        return { ok: false, error: "Lark error" }
    }

    function refresh() {
        if (!busy) error = ""
        if (!ordersProc.running) {
            loading = true
            ordersProc.killed = false
            ordersWatchdog.restart()
            ordersProc.running = true
        }
        if (buOptions.length === 0 && !optionsProc.running) optionsProc.running = true
    }

    // Record ids already handled once, persisted in the Db cache. `null` row = the
    // sync has never run on this machine (first run: only today's items are imported).
    function _loadSeen() {
        try {
            var row = Db.cacheGet("lark-seen")
            if (row) return JSON.parse(row.json)
        } catch (e) {}
        return null
    }

    function _remember(id) {
        if (!id) return
        var seen = _loadSeen()
        // Before the first sync there is no list yet; that run adds the id itself
        // (the todo carries lark_id, so it is never imported twice either way).
        if (seen === null || seen.indexOf(id) !== -1) return
        seen.push(id)
        Db.cachePut("lark-seen", JSON.stringify(seen))
    }

    // Pull now (the timer calls this too). Manual calls surface errors in syncError.
    function sync() {
        // Not while a task is being created: the half-made record would be imported
        // as a second todo. The next tick (or a manual sync) catches up.
        if (syncing || busy || !configured) return
        syncing = true
        syncError = ""
        syncProc.killed = false
        // Also ask about the records our todos point at, to drop the deleted ones.
        var ids = Db.loadTodos().map(function (t) { return t.lark_id })
            .filter(function (id) { return !!id })
        syncProc.command = [_taskScript, "assigned"].concat(ids)
        syncWatchdog.restart()
        syncProc.running = true
    }

    function _applySync(items, missing) {
        var seen = _loadSeen()
        var firstRun = seen === null
        var midnight = new Date()
        midnight.setHours(0, 0, 0, 0)
        // Without the todo list nothing can be imported: remember nothing, try again later.
        if (!todoData) return
        var plan = L.planSync(items, seen || [], Db.loadTodos(), midnight.getTime(), firstRun, missing)
        var i
        for (i = 0; i < plan.add.length; i++) {
            var a = plan.add[i]
            todoData.add(a.title, a.content, a.dueKey, null, a.larkId, !!a.coding)
        }
        for (i = 0; i < plan.done.length; i++) todoData.setDone(plan.done[i])
        for (i = 0; i < plan.rename.length; i++) todoData.rename(plan.rename[i].id, plan.rename[i].title)
        for (i = 0; i < plan.remove.length; i++) todoData.remove(plan.remove[i])
        if (plan.coding.length > 0) {
            var all = Db.loadTodos()
            for (i = 0; i < plan.coding.length; i++) {
                for (var j = 0; j < all.length; j++)
                    if (all[j].id === plan.coding[i].id) todoData.setLarkCoding(all[j].lark_id, plan.coding[i].coding)
            }
        }
        // Only now: ids are marked as handled after their todos exist.
        Db.cachePut("lark-seen", JSON.stringify(plan.seen))
        if (plan.add.length > 0) {
            var body = plan.add.slice(0, 5).map(function (x) { return "• " + x.title }).join("\n")
            if (plan.add.length > 5) body += "\n… +" + (plan.add.length - 5)
            Quickshell.execDetached(["notify-send", "-a", "Todo", "-i", "checkbox-checked-symbolic",
                "--", plan.add.length + " new from Lark", body])
        }
    }

    function _run(proc, watchdog, command) {
        proc.killed = false
        proc.command = command
        watchdog.restart()
        proc.running = true
    }

    // Create the task (and its local todo) under an existing order.
    function submit(task, orderId) {
        if (busy || !task || String(task.title).trim() === "" || !orderId) return
        busy = true
        error = ""
        _task = task
        // An order made here that still lacks its task: adopt the automation's one.
        _adopt = !!_newOrders[orderId]
        lastOrderId = orderId
        _createTask()
    }

    // Create a new order first, then the task under it.
    function submitWithNewOrder(task, orderTitle, bu, project) {
        if (busy || !task || String(task.title).trim() === ""
                || !L.validOrderForm(orderTitle, bu, project)) return
        busy = true
        error = ""
        _task = task
        lastOrderId = ""
        _adopt = false
        createProc.kind = "order"
        createProc.meta = { title: String(orderTitle).trim(), bu: bu, project: project }
        _run(createProc, createWatchdog, [_taskScript, "create-order",
            JSON.stringify(L.orderFields(orderTitle, bu, project, Date.now()))])
    }

    // Same task, same order as the failed attempt (the text may have been edited).
    function retry(task) {
        if (lastOrderId !== "") submit(task, lastOrderId)
    }

    function resetAttempt() {
        if (busy) return
        lastOrderId = ""
        _adopt = false
        error = ""
    }

    function _createTask() {
        createProc.kind = "task"
        createProc.meta = null
        var command = [_taskScript, "create-task",
            JSON.stringify(L.taskFields(_task.title, _task.content, _task.dateKey, lastOrderId))]
        if (_adopt) command.push("--adopt")
        _run(createProc, createWatchdog, command)
    }

    function _taskDone(id, url) {
        var t = _task
        _task = null
        if (_newOrders[lastOrderId]) {
            var rest = {}
            for (var k in _newOrders) if (k !== lastOrderId) rest[k] = true
            _newOrders = rest
        }
        lastOrderId = ""
        _adopt = false
        // Already there if a sync slipped in between Lark's write and this answer.
        var exists = Db.loadTodos().some(function (x) { return x.lark_id === id })
        if (todoData && !exists) todoData.add(t.title, t.content, t.dueKey, t.dueMinutes, id)
        _remember(id)
        Quickshell.execDetached(["notify-send", "-a", "Todo", "-i", "checkbox-checked-symbolic",
            "--", "Lark task created", t.title])
        taskCreated(url)
    }

    function startReview(title, content) {
        review = null
        reviewError = ""
        reviewing = true
        reviewProc.cancelled = false
        if (reviewProc.running) {
            // Let the old run die first; onExited starts the queued one.
            reviewProc.queued = [String(title), String(content)]
            reviewProc.cancelled = true
            reviewProc.running = false
            return
        }
        reviewProc.queued = null
        _run(reviewProc, reviewWatchdog, [_reviewScript, String(title), String(content)])
    }

    function cancelReview() {
        reviewProc.queued = null
        reviewing = false
        reviewWatchdog.stop()
        if (reviewProc.running) {
            reviewProc.cancelled = true
            reviewProc.running = false
        }
    }

    Process {
        id: ordersProc
        property bool killed: false
        command: [root._taskScript, "orders"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Stopped by its watchdog, which already reported: ignore the empty output.
                if (ordersProc.killed) { ordersProc.killed = false; return }
                var d = root._parse(this.text)
                ordersWatchdog.stop()
                root.loading = false
                if (d.ok && Array.isArray(d.orders)) root.orders = d.orders
                else root._fail(d.error || "Lark error")
            }
        }
    }

    Process {
        id: optionsProc
        command: [root._taskScript, "options"]
        stdout: StdioCollector {
            onStreamFinished: {
                var d = root._parse(this.text)
                if (d.ok) {
                    root.buOptions = d.bu || []
                    root.projectOptions = d.project || []
                } else {
                    root._fail(d.error || "Lark error")
                }
            }
        }
    }

    Process {
        id: createProc
        property bool killed: false
        property string kind: ""
        property var meta: null
        stdout: StdioCollector {
            onStreamFinished: {
                if (createProc.killed) { createProc.killed = false; return }
                var d = root._parse(this.text)
                createWatchdog.stop()
                if (!d.ok || !d.id) {
                    root._createFailed(d.error || "Lark error")
                    return
                }
                if (createProc.kind === "order") {
                    var m = createProc.meta
                    root.orders = [{ id: d.id, title: m.title, bu: m.bu, project: m.project,
                                     status: "L4. Đang code" }].concat(root.orders)
                    root.lastOrderId = d.id
                    root._adopt = true
                    var made = { }
                    for (var k in root._newOrders) made[k] = true
                    made[d.id] = true
                    root._newOrders = made
                    // Our own order: the sync must not hand it back as a todo.
                    root._remember(d.id)
                    root.orderCreated(d.id, m.title, m.bu, m.project)
                    // The task call starts once this process has exited — whichever of
                    // "stream finished" and "exited" comes last (see _chain).
                    createProc.chain = true
                    createWatchdog.restart()
                    Qt.callLater(root._chain)
                } else {
                    root.busy = false
                    root._taskDone(d.id, d.url || "")
                }
            }
        }
        property bool chain: false
        onExited: root._chain()
    }

    function _chain() {
        if (!createProc.chain || createProc.running) return
        createProc.chain = false
        _createTask()
    }

    // A process that cannot even start reports nothing, so each call has a deadline
    // (the scripts' own limits are 15 s per request / 60 s for the review).
    Timer {
        id: createWatchdog
        interval: 45000
        onTriggered: {
            createProc.chain = false
            if (createProc.running) { createProc.killed = true; createProc.running = false }
            root._createFailed("Lark did not answer — check Lark before retrying")
        }
    }
    Timer {
        id: ordersWatchdog
        interval: 60000
        onTriggered: {
            if (ordersProc.running) { ordersProc.killed = true; ordersProc.running = false }
            root.loading = false
            root._fail("Lark did not answer")
        }
    }
    Timer {
        id: reviewWatchdog
        interval: 70000
        onTriggered: {
            reviewProc.cancelled = true
            if (reviewProc.running) reviewProc.running = false
            root.reviewing = false
            root.reviewError = "review timed out"
        }
    }

    // ── todo ticked in the panel -> Lark ──
    // A record that is "Đang code" moves to "Chờ nghiệm thu" at 100 %; other states
    // are left alone (lark-task.sh finish decides). One request at a time; ticks made
    // meanwhile wait in the queue.
    property var _finishQueue: []

    Connections {
        target: root.todoData
        function onLarkTicked(larkId, title) {
            root._finishQueue = root._finishQueue.concat([{ action: "finish", id: larkId, title: title }])
            root._finishNext()
        }
    }

    // "Mark đang code" button of a Lark todo: the record moves to "Đang code"
    // (lark-task.sh start). Shares the queue with the tick updates.
    function markCoding(larkId, title) {
        if (!larkId) return
        _finishQueue = _finishQueue.concat([{ action: "start", id: larkId, title: title }])
        _finishNext()
    }

    // A deadline was set on a Lark todo: Lark gets the date if it has none yet
    // (lark-task.sh deadline). Shares the queue with the tick updates.
    function setDeadline(larkId, title, dateKey) {
        if (!larkId || !dateKey) return
        _finishQueue = _finishQueue.concat([{ action: "deadline", id: larkId, title: title, arg: String(dateKey) }])
        _finishNext()
    }

    // The next request starts only after the previous one has exited AND its output
    // was handled (the two signals come in either order; `current` belongs to the run
    // being handled until then).
    function _finishNext() {
        if (finishProc.running || (finishProc.current && !finishProc.handled)) return
        finishProc.current = null
        if (_finishQueue.length === 0) return
        finishProc.handled = false
        finishProc.current = _finishQueue[0]
        _finishQueue = _finishQueue.slice(1)
        var c = finishProc.current
        _run(finishProc, finishWatchdog, [_taskScript, c.action, c.id].concat(c.arg ? [c.arg] : []))
    }

    function _finishNote(urgent, summary, message) {
        var c = finishProc.current
        var args = ["notify-send", "-a", "Todo", "-i", urgent ? "dialog-warning-symbolic" : "checkbox-checked-symbolic"]
        if (urgent) args = args.concat(["-u", "critical"])
        Quickshell.execDetached(args.concat(["--", summary, (c ? c.title : "") + (message ? "\n" + message : "")]))
    }

    Process {
        id: finishProc
        property bool killed: false
        property bool handled: true
        property var current: null
        stdout: StdioCollector {
            onStreamFinished: {
                if (finishProc.killed) { finishProc.killed = false; return }
                var d = root._parse(this.text)
                finishWatchdog.stop()
                finishProc.handled = true
                Qt.callLater(root._finishNext)
                if (!d.ok) root._finishNote(true, "Lark not updated", d.error || "Lark error")
                else if (finishProc.current.action === "deadline") {
                    // Lark already had a date: kept as it is, nothing to report.
                    if (d.changed > 0) root._finishNote(false, "Lark: deadline set", "")
                } else if (finishProc.current.action === "start") {
                    // Shown at once; the next sync confirms (or corrects) it.
                    // d.coding: the record is "Đang code" now (also when it already was).
                    if (root.todoData) root.todoData.setLarkCoding(finishProc.current.id, !!d.coding)
                    root._finishNote(false, d.changed > 0 ? "Lark: Đang code"
                        : d.coding ? "Lark: already Đang code" : "Lark: not changed (already past Chờ code)", "")
                } else if (d.changed > 0) {
                    if (root.todoData) root.todoData.setLarkCoding(finishProc.current.id, false)
                    root._finishNote(false, "Lark: Chờ nghiệm thu, 100%", "")
                }
            }
        }
        onExited: Qt.callLater(root._finishNext)
    }
    Timer {
        id: finishWatchdog
        interval: 60000
        onTriggered: {
            if (finishProc.running) { finishProc.killed = true; finishProc.running = false }
            root._finishNote(true, "Lark not updated", "Lark did not answer")
            finishProc.handled = true
            Qt.callLater(root._finishNext)
        }
    }

    Process {
        id: syncProc
        property bool killed: false
        command: [root._taskScript, "assigned"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (syncProc.killed) { syncProc.killed = false; return }
                var d = root._parse(this.text)
                syncWatchdog.stop()
                root.syncing = false
                if (d.ok && Array.isArray(d.items)) {
                    root._applySync(d.items, Array.isArray(d.missing) ? d.missing : [])
                    root.lastSyncAt = Date.now()
                } else {
                    root.syncError = d.error || "Lark error"
                    if (d.error === "Lark not configured") root.configured = false
                }
            }
        }
    }
    Timer {
        id: syncWatchdog
        interval: 60000
        onTriggered: {
            if (syncProc.running) { syncProc.killed = true; syncProc.running = false }
            root.syncing = false
            root.syncError = "Lark did not answer"
        }
    }
    // First pull shortly after startup (network may not be up yet), then every 15 min.
    Timer {
        interval: 30000
        running: true
        onTriggered: root.sync()
    }
    Timer {
        interval: root.syncIntervalMs
        running: root.configured
        repeat: true
        onTriggered: root.sync()
    }

    Process {
        id: reviewProc
        property bool killed: false   // unused (cancelled covers it); set by _run
        property bool cancelled: false
        property var queued: null
        stdout: StdioCollector {
            onStreamFinished: {
                if (reviewProc.cancelled) return
                reviewWatchdog.stop()
                root.reviewing = false
                var d = root._parse(this.text)
                var r = d.ok ? L.parseReview(JSON.stringify({ title: d.title, content: d.content })) : null
                if (r) root.review = r
                else root.reviewError = d.error && d.error !== "Lark error" ? d.error : "review failed"
            }
        }
        onExited: {
            if (queued === null) return
            var q = queued
            queued = null
            cancelled = false
            root._run(reviewProc, reviewWatchdog, [root._reviewScript, q[0], q[1]])
        }
    }
}
