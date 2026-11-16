.pragma library

// Pure helpers for the "create a Lark task" flow of the todo panel: order search,
// form validation and the Lark Base field objects. Self-contained (no imports) so
// tests/run.mjs can eval it. The user fields (assignee) are added by
// scripts/lark-task.sh, which owns the credentials and ids.

// Lower-case and strip Vietnamese diacritics, so "dao tao" matches "Đào tạo".
function fold(s) {
    return String(s === null || s === undefined ? "" : s).toLowerCase()
        .normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/g, "d")
}

// Orders whose title / BU / project contain every word of the query.
function filterOrders(orders, query) {
    var words = fold(query).split(/\s+/).filter(function (w) { return w !== "" })
    if (words.length === 0) return orders
    return orders.filter(function (o) {
        var hay = fold(o.title + " " + o.bu + " " + o.project)
        return words.every(function (w) { return hay.indexOf(w) !== -1 })
    })
}

function validOrderForm(title, bu, project) {
    return String(title || "").trim() !== "" && String(bu || "").trim() !== ""
        && String(project || "").trim() !== ""
}

// yyyymmdd -> milliseconds at local midnight (what Lark date fields store).
function dateMs(dateKey) {
    return new Date(Math.floor(dateKey / 10000), Math.floor(dateKey / 100) % 100 - 1, dateKey % 100).getTime()
}

// Fields of a new row in the Tasks table. The start date always equals the work date.
function taskFields(title, note, dateKey, orderId) {
    var ms = dateMs(dateKey)
    var f = {
        "Công việc": String(title).trim(),
        "Order": [orderId],
        "Ngày thực hiện": ms,
        "Ngày bắt đầu task": ms,
        "Kết quả cuối ngày": "Chờ code"
    }
    var n = String(note === null || note === undefined ? "" : note).trim()
    if (n !== "") f["Link issue"] = n
    return f
}

// Fields of a new row in the Orders table.
function orderFields(title, bu, project, nowMs) {
    return {
        "Tiêu đề order": String(title).trim(),
        "BU order": bu,
        "Loại dự án": project,
        "Ngày order": nowMs,
        "Trạng thái": "L4. Đang code",
        "Phân loại": "Order mới",
        "Ưu tiên": "Medium"
    }
}

// OpenCode's answer -> {title, content}, or null when it is not usable. The model
// may wrap the JSON object in a code fence or add a sentence around it.
function parseReview(raw) {
    var s = String(raw === null || raw === undefined ? "" : raw)
    var a = s.indexOf("{"), b = s.lastIndexOf("}")
    if (a === -1 || b <= a) return null
    var o
    try { o = JSON.parse(s.slice(a, b + 1)) } catch (e) { return null }
    if (!o || typeof o.title !== "string") return null
    var title = o.title.replace(/\s+/g, " ").trim().slice(0, 200)
    if (title === "") return null
    var content = typeof o.content === "string"
        ? o.content.replace(/\r\n?/g, "\n").trim().slice(0, 4000) : ""
    return { title: title, content: content }
}

// Timestamp (ms) -> yyyymmdd of the local calendar day, or null.
function msToKey(ms) {
    if (ms === null || ms === undefined) return null
    var d = new Date(ms)
    return d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate()
}

// Decide what one poll of Lark changes locally.
//   items   [{id, kind: "task"|"order", title, content, dateMs, created, done, coding, orderId}]
//           assigned to the user; orderId (tasks only) is the order the task belongs to
//   seenIds record ids already handled once (imported, created from the panel, or skipped)
//   todos   local todos ({id, lark_id, done, title})
//   missingIds (optional) record ids Lark reports as no longer existing
// Returns {add: [{larkId, title, content, dueKey}], done: [todoId],
//          rename: [{id, title}], remove: [todoId], coding: [{id, coding}], seen: [ids]}.
// add entries carry coding: true when their record is "Đang code".
// A todo whose Lark record was deleted is removed (done or not).
// An item is imported once: deleting its todo locally does not bring it back. On the
// first run only items created since cutoffMs are imported (the backlog is remembered,
// not dumped into the list). Finishing on Lark ticks the linked todo; never the reverse.
// Open items with the same order id (an order and its tasks, or several tasks of one
// order) are one piece of work and share a single "Task/Order: …" todo: linked to the
// task when there is just one, to the order otherwise. A member that shows up after
// the group already has a todo only relabels that todo.
function planSync(items, seenIds, todos, cutoffMs, firstRun, missingIds) {
    var seen = {}, seenList = []
    function remember(id) { if (!seen[id]) { seen[id] = true; seenList.push(id) } }
    ;(seenIds || []).forEach(remember)
    var byLark = {}
    ;(todos || []).forEach(function (t) { if (t.lark_id) byLark[t.lark_id] = t })
    function clean(s) { return String(s || "").replace(/\s+/g, " ").trim() }
    function text(s) { return String(s || "").trim() }
    function groupId(it) { return it.kind === "order" ? it.id : (it.orderId || "") }

    // Open items per order id.
    var groups = {}
    ;(items || []).forEach(function (it) {
        if (!it || !it.id || it.done) return
        var gid = groupId(it)
        if (gid === "") return
        var g = groups[gid] || (groups[gid] = { id: gid, order: null, tasks: [], added: false })
        if (it.kind === "order") g.order = it
        else g.tasks.push(it)
    })
    function todoOf(g) {
        if (byLark[g.id]) return byLark[g.id]
        for (var i = 0; i < g.tasks.length; i++) if (byLark[g.tasks[i].id]) return byLark[g.tasks[i].id]
        return null
    }

    var add = [], done = [], rename = [], renamed = {}
    ;(items || []).forEach(function (it) {
        if (!it || !it.id) return
        var todo = byLark[it.id]
        if (todo && it.done && !todo.done) done.push(todo.id)
        if (seen[it.id]) return
        remember(it.id)
        var title = clean(it.title)
        if (title === "" || it.done || todo) return
        if (firstRun && !(it.created >= cutoffMs)) return

        var g = groups[groupId(it)]
        if (!g || (g.order ? 1 : 0) + g.tasks.length < 2) {
            var single = { larkId: it.id, title: it.kind === "order" ? "Order: " + title : title,
                           content: text(it.content), dueKey: msToKey(it.dateMs) }
            if (it.coding) single.coding = true
            add.push(single)
            return
        }
        if (g.added) return
        var existing = todoOf(g)
        if (existing) {
            var old = String(existing.title || "")
            if (old.indexOf("Task/Order: ") !== 0 && !renamed[existing.id]) {
                renamed[existing.id] = true
                rename.push({ id: existing.id, title: "Task/Order: " + old.replace(/^Order: /, "") })
            }
            return
        }
        g.added = true
        var one = g.tasks.length === 1 ? g.tasks[0] : null
        var orderText = g.order ? text(g.order.content) : ""
        var content
        if (one) {
            content = text(one.content) || orderText
        } else {
            var list = g.tasks.map(function (t) { return "- " + clean(t.title) }).join("\n")
            content = orderText !== "" && list !== "" ? orderText + "\n\n" + list : orderText + list
        }
        var dates = g.tasks.map(function (t) { return t.dateMs })
            .filter(function (d) { return d !== null && d !== undefined })
        var merged = {
            larkId: one ? one.id : g.id,
            title: "Task/Order: " + (g.order ? clean(g.order.title) || title : title),
            content: content,
            dueKey: dates.length > 0 ? msToKey(Math.min.apply(null, dates)) : null
        }
        // Being coded = the record the todo is linked to is "Đang code".
        if (one ? one.coding : (g.order && g.order.coding)) merged.coding = true
        add.push(merged)
    })
    // Existing todos take over the "Đang code" state of their record when it changed.
    var coding = []
    ;(items || []).forEach(function (it) {
        var t = it && it.id ? byLark[it.id] : null
        if (t && !!t.lark_coding !== !!it.coding) coding.push({ id: t.id, coding: !!it.coding })
    })
    var missing = {}
    ;(missingIds || []).forEach(function (id) { missing[id] = true })
    var remove = (todos || []).filter(function (t) { return t.lark_id && missing[t.lark_id] })
        .map(function (t) { return t.id })
    return { add: add, done: done, rename: rename, remove: remove, coding: coding, seen: seenList }
}
