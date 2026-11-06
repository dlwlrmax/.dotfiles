import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import "../common/ListSync.js" as Sync
import "Highlight.js" as Hl
import "Group.js" as Grp

Item {
    id: root
    property Theme theme: ThemeStore
    property bool active: false
    property var dataSource: null
    property var notifTimes: ({})
    property bool dnd: !!(dataSource && dataSource.dnd)

    // Which tab is shown: "unread" (live + unread history) or "read".
    property string tab: "unread"

    // Search over app name, title and body; empty = no filter. Case- and
    // diacritic-insensitive ("thuy anh" matches "Thùy Anh").
    property string query: ""
    readonly property string _needle: Hl.fold(root.query.trim())
    onActiveChanged: if (!active) searchField.text = ""

    // Live (currently active) notifications — shown first in the Unread tab.
    property var reversedNotifs: dataSource && dataSource.activeNotifs
        ? dataSource.activeNotifs.slice().reverse() : []
    property var shownLive: root.reversedNotifs.filter(root.matches)
    // Unread tab: live notifications, then unread history rows, grouped as one
    // newest-first sequence so a run from one app is a single card either way.
    property var groupedNotifs: root.groupNotifications(root.tab === "unread"
        ? root.byTimeDesc(root.shownLive.concat(root.pageRows(root.shownUnread, root.unreadLimit)))
        : root.shownLive)
    // Read tab: same merging over read history rows.
    property var groupedRead: root.groupNotifications(root.tab === "read"
        ? root.pageRows(root.shownRead, root.readLimit) : [])

    // DB row ids backing the live notifications, so history can skip them and
    // avoid showing the same notification twice (once live, once as history).
    // NOTE: plain binding (not IIFE) so it re-evaluates whenever activeNotifs
    // is reassigned (concat on add, slice on close/dismiss, reset on clearAll).
    property var liveIds: {
        var m = {}
        var a = dataSource && dataSource.activeNotifs ? dataSource.activeNotifs : []
        for (var i = 0; i < a.length; i++)
            if (a[i] && a[i]._dbId !== undefined && a[i]._dbId !== null)
                m[a[i]._dbId] = true
        return m
    }

    property var historyAll: dataSource && dataSource.history ? dataSource.history : []
    property var historyRows: root.historyAll.filter(function(r) {
        return !(r.id !== undefined && root.liveIds[r.id])
    })
    property var unreadRows: root.historyRows.filter(function(r) { return r.read !== 1 })
    property var readRows: root.historyRows.filter(function(r) { return r.read === 1 })
    property var shownUnread: root.unreadRows.filter(root.matches)
    property var shownRead: root.readRows.filter(root.matches)
    readonly property bool searching: root._needle !== ""

    property int unreadCount: root.reversedNotifs.length + root.unreadRows.length
    property int totalCount: root.unreadCount

    signal close()

    // Card lists are ListModels of keys, updated in place: a click or an incoming notification
    // only touches the cards that changed, so the others keep their expanded state.
    readonly property int pageSize: 15
    property int unreadLimit: pageSize
    property int readLimit: pageSize

    ListModel { id: groupModel }
    ListModel { id: readModel }
    property var groupByKey: ({})

    // Infinite scroll: grow the active tab's page when the view nears the bottom.
    // Also runs when content grows, so a short first page keeps filling the viewport.
    function loadMore() {
        if (tab === "unread" && shownUnread.length > unreadLimit)
            unreadLimit += pageSize
        else if (tab === "read" && shownRead.length > readLimit)
            readLimit += pageSize
    }

    function syncLists() {
        var g = {}, i
        for (i = 0; i < groupedNotifs.length; i++) g[groupedNotifs[i].key] = groupedNotifs[i]
        for (i = 0; i < groupedRead.length; i++) g[groupedRead[i].key] = groupedRead[i]
        groupByKey = g           // map first: delegates re-read their group from it
        // Only the visible tab builds cards, and only a page of rows at a time:
        // every delegate is instantiated even when its tab is hidden.
        Sync.sync(groupModel, groupedNotifs.map(function (x) { return String(x.key) }))
        Sync.sync(readModel, groupedRead.map(function (x) { return String(x.key) }))
    }

    onGroupedNotifsChanged: syncLists()
    onGroupedReadChanged: syncLists()
    on_NeedleChanged: {
        unreadLimit = pageSize
        readLimit = pageSize
        syncLists()
    }
    onTabChanged: {
        unreadLimit = pageSize
        readLimit = pageSize
        syncLists()
    }
    Component.onCompleted: syncLists()

    clip: true
    implicitWidth: theme.panelWidthS
    // Content height (14px margins + header + 10 spacing + tab bar + 10 spacing
    // + search + 10 spacing + list),
    // capped at 640px (or the screen under the bar, if smaller); the list scrolls beyond that.
    readonly property real maxHeight: {
        var scr = root.QsWindow.window ? root.QsWindow.window.screen : null
        return Math.min(640, scr ? scr.height - theme.barHeight - 24 : 640)
    }
    implicitHeight: Math.min(maxHeight, 14 + panelHeader.implicitHeight + 10 + tabBar.implicitHeight + 10 + searchField.implicitHeight + 10 + contentCol.implicitHeight + 14)

    // Type anywhere in the panel to search; Esc clears the query first, then closes.
    Keys.onPressed: event => {
        if (searchField.activeFocus) return
        var t = event.text
        if (!t || t.length !== 1 || t.charCodeAt(0) < 32 || t.charCodeAt(0) === 127) return
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
        searchField.forceActiveFocus()
        searchField.insert(searchField.cursorPosition, t)
        event.accepted = true
    }

    PanelBackground {
        anchors.fill: parent
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        PanelHeader {
            id: panelHeader
            theme: root.theme
            title: "Notifications" + (root.totalCount > 0 ? " (" + root.totalCount + ")" : "")
            onClose: root.close()

            Badge {
                theme: root.theme
                text: "Clear all"
                clr: theme.blue
                clickable: true
                onClicked: {
                    if (root.dataSource && root.dataSource.clearAll)
                        root.dataSource.clearAll()
                }
            }
        }

        RowLayout {
            id: tabBar
            Layout.fillWidth: true
            spacing: 6

            Badge {
                Layout.fillWidth: true
                implicitHeight: 26
                theme: root.theme
                readonly property int n: root.searching
                    ? root.shownLive.length + root.shownUnread.length : root.unreadCount
                text: "Unread" + (n > 0 ? " (" + n + ")" : "")
                pixelSize: theme.fontSize - 1
                clr: theme.blue
                solid: root.tab === "unread"
                clickable: true
                onClicked: root.tab = "unread"
            }

            Badge {
                Layout.fillWidth: true
                implicitHeight: 26
                theme: root.theme
                readonly property int n: root.shownRead.length
                text: "Read" + (n > 0 ? " (" + n + ")" : "")
                pixelSize: theme.fontSize - 1
                clr: theme.blue
                solid: root.tab === "read"
                clickable: true
                onClicked: root.tab = "read"
            }
        }

        TextField {
            id: searchField
            Layout.fillWidth: true
            implicitHeight: 28
            // Source of truth for root.query (one-way: field -> query).
            onTextChanged: root.query = text
            placeholderText: "Search notifications…"
            color: theme.text
            placeholderTextColor: theme.overlay0
            font.pixelSize: theme.fontSizeMin
            font.family: theme.fontUi
            selectByMouse: true
            leftPadding: 8
            rightPadding: clearSearch.visible ? clearSearch.width + 12 : 8
            background: Rectangle {
                radius: theme.radiusMd
                color: theme.surface0
                border.color: searchField.activeFocus ? theme.blue : "transparent"
                border.width: 1
            }
            // Non-empty: Esc clears. Empty: falls through to the overlay, which closes.
            Keys.onEscapePressed: event => {
                if (text === "") { event.accepted = false; return }
                text = ""
            }

            Text {
                id: clearSearch
                visible: searchField.text !== ""
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: Glyphs.close
                color: theme.subtext0
                font.family: theme.font
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: searchField.text = ""
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: scroll
                anchors.fill: parent
                contentHeight: contentCol.implicitHeight
                clip: true
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                readonly property bool nearEnd: contentHeight - (contentY + height) < 240
                onNearEndChanged: if (nearEnd) root.loadMore()
                onContentHeightChanged: if (nearEnd) root.loadMore()

                ColumnLayout {
                    id: contentCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 12

                    // ── Unread (live notifications on top, then unread history) ──
                    ColumnLayout {
                        visible: root.tab === "unread"
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "Mark all read"
                                color: theme.blue
                                font.pixelSize: theme.fontSize - 1
                                font.family: theme.font
                                visible: root.unreadCount > 0 && !root.searching

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var live = root.reversedNotifs
                                        for (var i = 0; i < live.length; ++i)
                                            if (live[i].dismiss) live[i].dismiss()
                                        if (root.dataSource && root.dataSource.markAllRead)
                                            root.dataSource.markAllRead()
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.searching
                                ? root.shownLive.length + root.shownUnread.length === 0
                                : root.unreadCount === 0
                            text: root.searching ? "No matches"
                                : root.dnd ? "Do Not Disturb is on" : "Nothing unread"
                            color: theme.subtext0
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                        }

                        // Live notifications — grouped by app, with dismiss,
                        // action buttons, and urgency styling.
                        Repeater {
                            model: groupModel
                            delegate: activeGroupDelegate
                        }

                        Text {
                            visible: root.shownUnread.length > root.unreadLimit
                            Layout.alignment: Qt.AlignHCenter
                            text: (root.shownUnread.length - root.unreadLimit) + " more…"
                            color: theme.subtext0
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                        }
                    }

                    // ── Read ───────────────────────────────────
                    ColumnLayout {
                        visible: root.tab === "read"
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "Clear read"
                                color: theme.blue
                                font.pixelSize: theme.fontSize - 1
                                font.family: theme.font
                                visible: root.readRows.length > 0 && !root.searching

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.dataSource && root.dataSource.clearRead)
                                            root.dataSource.clearRead()
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.shownRead.length === 0
                            text: root.searching ? "No matches" : "No read notifications"
                            color: theme.subtext0
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                        }

                        Repeater {
                            model: readModel
                            delegate: activeGroupDelegate
                        }

                        Text {
                            visible: root.shownRead.length > root.readLimit
                            Layout.alignment: Qt.AlignHCenter
                            text: (root.shownRead.length - root.readLimit) + " more…"
                            color: theme.subtext0
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                        }
                    }
                }
            }
        }
    }

    // ── delegates ──────────────────────────────────────────────

    // One card per run of same-app notifications (see groupNotifications).
    Component {
        id: activeGroupDelegate
        NotificationCard {
            required property string k
            readonly property var modelData: root.groupByKey[k] || ({ messages: [], key: k })
            Layout.fillWidth: true
            width: contentCol.width
            theme: root.theme
            notifData: modelData.view || ({})
            // Live ids index notifTimes; history ids live in another space.
            notifTimes: modelData.latest && modelData.latest.dismiss ? root.notifTimes : ({})
            count: modelData.messages.length
            highlight: root._needle
            // Read tab runs are history rows with read === 1.
            read: !!modelData.latest && !modelData.latest.dismiss && modelData.latest.read === 1
            unread: !read
            // Live entries stay under Unread while active, so both read-click
            // and × retire them; history rows delete on × and mark read on click.
            onDismissRequest: function() { root.forEachMessage(modelData, root.dismissItem) }
            onMarkRead: function() { root.forEachMessage(modelData, root.readItem) }
        }
    }

    // ── helpers ────────────────────────────────────────────────

    // History row id -> folded search text. Filled lazily and mutated in place
    // (no change signal), so a keystroke only re-runs indexOf. Rows are
    // immutable apart from `read`; the cache is dropped on every history reload.
    property var _foldCache: ({})
    onHistoryAllChanged: _foldCache = ({})

    function _hay(n) {
        return Hl.fold((n.appName || "") + " " + (n.summary || "") + " "
            + Sanitize.visibleText(n.body))
    }

    function matches(n) {
        if (!root._needle) return true
        if (!n) return false
        var hay
        if (n.id !== undefined && n._dbId === undefined) {
            hay = root._foldCache[n.id]
            if (hay === undefined) hay = root._foldCache[n.id] = root._hay(n)
        } else {
            hay = root._hay(n)   // live notifications: few, and not plain rows
        }
        return hay.indexOf(root._needle) >= 0
    }

    // Newest first. Only neighbours from the same app share a card; another
    // app in between starts a new one. Key = app + oldest member's id, so it
    // stays put while newer messages join.
    function groupNotifications(notifs) {
        var groups = []
        var cur = null
        for (var i = 0; i < notifs.length; ++i) {
            var notif = notifs[i]
            var appKey = Grp.appKey(notif)
            if (!cur || cur.appKey !== appKey) {
                cur = { appKey: appKey, key: "", appName: notif.appName || "Unknown",
                        latest: notif, messages: [], view: null }
                groups.push(cur)
            }
            cur.messages.push(notif)
            // History rows have their own id space: prefix keeps keys unique.
            cur.key = appKey + "#" + (notif.dismiss ? "" : "h") + notif.id
        }
        for (var g = 0; g < groups.length; ++g)
            groups[g].view = root.mergedView(groups[g].key, groups[g].messages)
        return groups
    }

    // Merged views keep their identity while the run is unchanged: a fresh
    // object per call would rebuild every body line on each history reload or
    // search keystroke. Mutated in place (no change signal); dropped when big.
    property var _viewCache: ({})

    function mergedView(key, messages) {
        if (messages.length === 1) return messages[0]
        var sig = ""
        for (var i = 0; i < messages.length; ++i) {
            var m = messages[i]
            sig += (m.dismiss ? "" : "h") + m.id + "\u0001" + (m.summary || "")
                + "\u0001" + (m.body || "") + "\u0002"
        }
        var hit = root._viewCache[key]
        if (hit && hit.sig === sig) return hit.view
        if (Object.keys(root._viewCache).length > 400) root._viewCache = ({})
        var view = Grp.mergedView(messages)
        root._viewCache[key] = { sig: sig, view: view }
        return view
    }

    // First `limit` rows, then on to the end of the run the last one belongs
    // to: a run cut mid-way would change its key (oldest member) and rebuild
    // its card when the next page loads.
    function pageRows(rows, limit) {
        if (rows.length <= limit) return rows
        var end = limit
        var key = Grp.appKey(rows[limit - 1])
        while (end < rows.length && Grp.appKey(rows[end]) === key) end++
        return rows.slice(0, end)
    }

    // Live notifications stay until dismissed, so one can be older than
    // history rows below it: order the mix by time, newest first.
    function byTimeDesc(list) {
        var t = function(n) {
            var v = n.dismiss ? (root.notifTimes[n.id] || n.timestamp || 0) : (n.timestamp || 0)
            return v || Date.now() / 1000     // unknown time: treat as just now
        }
        return list.map(function(n, i) { return { n: n, t: t(n), i: i } })
            .sort(function(a, b) { return b.t - a.t || a.i - b.i })
            .map(function(x) { return x.n })
    }

    function forEachMessage(group, fn) {
        var msgs = group && group.messages ? group.messages.slice() : []
        for (var i = 0; i < msgs.length; ++i) fn(msgs[i])
    }

    // Clear = done: mark the backing row read so it drops into Read once its
    // live entry is gone, instead of resurfacing as Unread.
    function retireLive(notif) {
        if (!notif) return
        var dbId = notif._dbId
        if (dbId !== undefined && dbId !== null && root.dataSource)
            root.dataSource.markRead(dbId)
        if (notif.dismiss) notif.dismiss()
    }

    // Group members are live notifications (have dismiss) or history rows.
    // Under Unread, × only marks read (the row moves to Read, nothing is lost);
    // under Read it deletes the row.
    function dismissItem(n) {
        if (!n) return
        if (n.dismiss) root.retireLive(n)
        else if (!root.dataSource) return
        else if (n.read === 1) root.dataSource.deleteHistoryRow(n.id)
        else root.dataSource.markRead(n.id)
    }

    function readItem(n) {
        if (!n) return
        if (n.dismiss) root.retireLive(n)
        else if (root.dataSource && n.read !== 1) root.dataSource.markRead(n.id)
    }
}
