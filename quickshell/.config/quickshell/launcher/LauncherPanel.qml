import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property bool active: false
    signal close()
    signal appLaunched()

    implicitWidth: 620
    implicitHeight: 500
    focus: true

    property string query: ""
    property var allEntries: []
    property var filteredEntries: []
    property int selectedIndex: 0
    property bool searchMode: false  // false = normal (navigate), true = insert (type)
    property string _recentDir: Quickshell.env("HOME") + "/.cache/quickshell"
    property string _recentFile: _recentDir + "/recent-apps.json"
    property var recentApps: []
    property var _recentMap: ({})  // id → timestamp for O(1) lookup
    property bool _suppressFilter: false

    // ── load .desktop entries via shell script ──

    function loadEntries() {
        if (!loadProc.running) loadProc.running = true
    }

    Process {
        id: loadProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/desktop-entries.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim())
                    var next = []
                    for (var i = 0; i < data.length; i++) {
                        var e = data[i]
                        if (e.noDisplay) continue
                        next.push({
                            id: e.id,
                            name: e.name || e.id,
                            genericName: e.genericName || "",
                            icon: e.icon || "",
                            exec: e.exec || "",
                            categories: e.categories || "",
                            keywords: e.keywords || "",
                            comment: e.comment || "",
                            terminal: e.terminal
                        })
                    }
                    root.allEntries = next
                    root.applyFilter()
                } catch (ex) {
                    console.log("Launcher: parse error", ex.message)
                }
            }
        }
    }

    Timer {
        id: loadTimer
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            if (root.allEntries.length > 0) {
                running = false
                return
            }
            if (!loadProc.running) loadProc.running = true
        }
    }

    Timer {
        id: refreshTimer
        interval: 300000
        repeat: true
        running: true
        onTriggered: loadEntries()
    }

    // ── recent apps ──

    function loadRecent() {
        recentReadProc.running = true
    }

    Process {
        id: recentReadProc
        command: ["cat", root._recentFile]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim())
                    root.recentApps = data
                    root._buildRecentMap()
                    root.applyFilter()
                } catch (ex) {
                    root.recentApps = []
                    root._recentMap = ({})
                }
            }
        }
    }

    function _buildRecentMap() {
        var m = ({})
        for (var i = 0; i < root.recentApps.length; i++) {
            m[root.recentApps[i].id] = root.recentApps[i].time
        }
        root._recentMap = m
    }

    function _getRecencyBoost(id) {
        var t = root._recentMap[id]
        if (t === undefined) return 0
        var now = Math.floor(Date.now() / 1000)
        var diff = now - t
        if (diff < 3600) return 1000
        if (diff < 14400) return 600
        if (diff < 86400) return 300
        if (diff < 604800) return 100
        return 20
    }

    function markRecent(entryId) {
        var now = Math.floor(Date.now() / 1000)
        for (var i = 0; i < root.recentApps.length; i++) {
            if (root.recentApps[i].id === entryId) {
                root.recentApps.splice(i, 1)
                break
            }
        }
        root.recentApps.unshift({ id: entryId, time: now })
        while (root.recentApps.length > 30) root.recentApps.pop()
        root._buildRecentMap()
        root._saveRecent()
    }

    function _saveRecent() {
        var json = JSON.stringify(root.recentApps)
        var escaped = json.replace(/'/g, "'\\''")
        recentWriteProc.command = [
            "bash", "-c",
            "mkdir -p " + root._recentDir + " && echo '" + escaped + "' > " + root._recentFile
        ]
        recentWriteProc.running = true
    }

    Process {
        id: recentWriteProc
        command: ["true"]
    }

    // ── filter / match ──

    function _fuzzyMatch(text, ql) {
        var ni = 0
        for (var i = 0; i < ql.length; i++) {
            var idx = text.indexOf(ql[i], ni)
            if (idx === -1) return -1
            ni = idx + 1
        }
        return ni - ql.length  // position of first matched char
    }

    function scoreEntry(entry, q) {
        if (!q) return 1
        var ql = q.toLowerCase()
        var name = (entry.name || "").toLowerCase()

        // exact match → highest
        if (name === ql) return 1000 + root._getRecencyBoost(entry.id)

        // prefix match
        if (name.indexOf(ql) === 0) return 500 + root._getRecencyBoost(entry.id)

        // substring match in name
        if (name.indexOf(ql) !== -1) return 100 + root._getRecencyBoost(entry.id)

        // fuzzy sequential match in name (all chars in order, gaps allowed)
        var firstPos = root._fuzzyMatch(name, ql)
        if (firstPos !== -1) {
            var score = 30 + Math.max(0, 10 - firstPos)
            return score + root._getRecencyBoost(entry.id)
        }

        // generic/keywords/comment substring match (low priority, no recency)
        var generic = (entry.genericName || "").toLowerCase()
        var keywords = (entry.keywords || "").toLowerCase()
        var comment = (entry.comment || "").toLowerCase()
        if (generic.indexOf(ql) !== -1 || keywords.indexOf(ql) !== -1 || comment.indexOf(ql) !== -1) {
            return 2
        }

        return 0
    }

    function applyFilter() {
        var q = query.trim()
        if (!q) {
            // Recent apps first, then rest alphabetically
            var recent = []
            var rest = []
            for (var i = 0; i < root.allEntries.length; i++) {
                var e = root.allEntries[i]
                if (root._recentMap[e.id] !== undefined)
                    recent.push(e)
                else
                    rest.push(e)
            }
            recent.sort(function(a, b) {
                return root._recentMap[b.id] - root._recentMap[a.id]
            })
            rest.sort(function(a, b) {
                return (a.name || "").localeCompare(b.name || "")
            })
            filteredEntries = recent.concat(rest).slice(0, 50)
            selectedIndex = 0
            return
        }
        var scored = []
        for (var i = 0; i < allEntries.length; i++) {
            var s = scoreEntry(allEntries[i], q)
            if (s > 0) scored.push({ entry: allEntries[i], score: s })
        }
        scored.sort(function (a, b) { return b.score - a.score })
        filteredEntries = scored.slice(0, 50).map(function (x) { return x.entry })
        selectedIndex = 0
    }

    function launch(entry) {
        if (!entry) return
        root.markRecent(entry.id)
        Quickshell.execDetached({
            command: ["gtk-launch", entry.id],
            workingDirectory: Quickshell.env("HOME")
        })
        appLaunched()
        close()
    }

    function moveSelection(delta) {
        if (filteredEntries.length === 0) return
        var n = filteredEntries.length
        selectedIndex = ((selectedIndex + delta) % n + n) % n
        list.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    function escapeHtml(str) {
        return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    }

    function highlightText(text, query, hlColor) {
        if (!query || !text) return escapeHtml(text || "")
        var lower = text.toLowerCase()
        var ql = query.toLowerCase()
        var result = ""
        var ni = 0
        for (var i = 0; i < ql.length; i++) {
            var idx = lower.indexOf(ql[i], ni)
            if (idx < 0) continue
            if (idx > ni) result += escapeHtml(text.substring(ni, idx))
            result += "<span style='color:" + hlColor + ";font-weight:bold'>" + escapeHtml(text[idx]) + "</span>"
            ni = idx + 1
        }
        if (ni < text.length) result += escapeHtml(text.substring(ni))
        return result
    }

    function reset() {
        query = ""
        selectedIndex = 0
    }

    onSearchModeChanged: {
        searchField.focus = root.searchMode
        if (root.searchMode) {
            searchField.selectAll()
            searchField.forceActiveFocus()
        } else {
            root.forceActiveFocus()
        }
    }

    Keys.onPressed: function(event) {
        // Esc always closes (both modes)
        if (event.key === Qt.Key_Escape) {
            event.accepted = true
            close()
            return
        }

        if (root.searchMode) {
            // ── INSERT MODE: only ↑↓ P/N and ↵ reach here (text goes to TextField) ──
            if (event.key === Qt.Key_Up || ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_P)) {
                event.accepted = true; moveSelection(-1); return
            }
            if (event.key === Qt.Key_Down || ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_N)) {
                event.accepted = true; moveSelection(1); return
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true
                if (filteredEntries.length > 0) launch(filteredEntries[selectedIndex])
                return
            }
            return
        }

        // ── NORMAL MODE ──
        if (event.key === Qt.Key_J || ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_N)) {
            event.accepted = true; moveSelection(1); return
        }
        if (event.key === Qt.Key_K || ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_P)) {
            event.accepted = true; moveSelection(-1); return
        }

        event.accepted = true
        switch (event.key) {
            case Qt.Key_Down: moveSelection(1); break
            case Qt.Key_Up: moveSelection(-1); break
            case Qt.Key_Slash:
            case Qt.Key_I: root.searchMode = true; break
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (filteredEntries.length > 0) launch(filteredEntries[selectedIndex])
                break
            default:
                var ch = event.text
                if (ch.length > 0 && ch.charCodeAt(0) >= 32) {
                    root.searchMode = true
                    query = ch
                    applyFilter()
                } else {
                    event.accepted = false
                }
        }
    }

    onQueryChanged: { if (!root._suppressFilter) applyFilter() }

    onActiveChanged: {
        if (active) {
            query = ""
            selectedIndex = 0
            root.searchMode = true  // start in insert mode
            loadEntries()
            Qt.callLater(function () {
                searchField.forceActiveFocus()
                searchField.focus = true
            })
        }
    }

    Component.onCompleted: loadRecent()

    // ── UI ──

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: theme.color
        border.color: theme.surface0
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // search field
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                radius: 8
                color: theme.mantle
                border.color: root.searchMode ? theme.green : theme.lavender
                border.width: root.searchMode ? 1 : 2

                TextField {
                    id: searchField
                    anchors.fill: parent
                    anchors.rightMargin: 14
                    anchors.leftMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    background: Item {}
                    color: theme.text
                    font.pixelSize: theme.fontSize + 3
                    font.family: theme.font
                    placeholderText: root.searchMode ? "Search apps…" : "press / to search"
                    placeholderTextColor: theme.surface1
                    text: root.query
                    onTextChanged: root.query = text
                    selectByMouse: true
                    readOnly: !root.searchMode
                    focus: root.searchMode

                    property bool _lastWasJ: false

                    Timer { id: jjReset; interval: 250; onTriggered: searchField._lastWasJ = false }

                    Keys.onPressed: function(event) {
                        var ctrl = event.modifiers & Qt.ControlModifier

                        // Enter/Return → launch selected
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            event.accepted = true
                            if (root.filteredEntries.length > 0)
                                root.launch(root.filteredEntries[root.selectedIndex])
                            return
                        }

                        // Ctrl+P/N → nav up/down
                        if (ctrl && event.key === Qt.Key_P) {
                            event.accepted = true; root.moveSelection(-1); return
                        }
                        if (ctrl && event.key === Qt.Key_N) {
                            event.accepted = true; root.moveSelection(1); return
                        }

                        // Ctrl+C → normal mode
                        if (ctrl && event.key === Qt.Key_C) {
                            event.accepted = true
                            root.searchMode = false
                            return
                        }

                        // Ctrl+A → cursor to start
                        if (ctrl && event.key === Qt.Key_A) {
                            event.accepted = true
                            cursorPosition = 0
                            return
                        }

                        // Ctrl+E → cursor to end
                        if (ctrl && event.key === Qt.Key_E) {
                            event.accepted = true
                            cursorPosition = text.length
                            return
                        }

                        // Ctrl+W → delete word backward
                        if (ctrl && event.key === Qt.Key_W) {
                            event.accepted = true
                            var pos = cursorPosition
                            var txt = text
                            if (pos === 0) return
                            if (selectionStart !== selectionEnd) {
                                remove(selectionStart, selectionEnd)
                                return
                            }
                            var end = pos
                            while (end > 0 && txt[end - 1] === ' ') end--
                            var start = end
                            while (start > 0 && txt[start - 1] !== ' ') start--
                            remove(start, pos)
                            return
                        }

                        // jj (quick) → normal mode, pop last j
                        if (root.searchMode && event.key === Qt.Key_J) {
                            if (_lastWasJ) {
                                _lastWasJ = false
                                jjReset.stop()
                                root._suppressFilter = true
                                root.query = root.query.slice(0, -1)
                                root._suppressFilter = false
                                root.searchMode = false
                                root.applyFilter()
                                event.accepted = true
                                return
                            }
                            _lastWasJ = true
                            jjReset.restart()
                            return  // let TextField type the first j
                        }

                        _lastWasJ = false
                    }
                }
            }

            // results list
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    spacing: 6
                    model: root.filteredEntries
                    currentIndex: root.selectedIndex
                    highlightFollowsCurrentItem: true
                    boundsBehavior: Flickable.StopAtBounds
                    visible: root.filteredEntries.length > 0

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        width: list.width
                        height: 42

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 6
                            color: row.index === root.selectedIndex ? theme.surface0 : "transparent"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            AppIcon {
                                appId: row.modelData.id
                                fallbackGlyph: "󰅬"
                                size: 20
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                fallbackIcon: "application-x-executable"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    id: nameText
                                    textFormat: Text.RichText
                                    text: root.highlightText(row.modelData.name, root.query, root.theme.peach)
                                    color: theme.text
                                    font.pixelSize: theme.fontSize + 1
                                    font.family: theme.font
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    visible: row.modelData.genericName.length > 0
                                    text: row.modelData.genericName
                                    color: theme.subtext0
                                    font.pixelSize: theme.fontSize - 1
                                    font.family: theme.font
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.selectedIndex = row.index
                            onClicked: root.launch(row.modelData)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.filteredEntries.length === 0
                    text: root.allEntries.length === 0 ? "loading apps…" :
                         root.query.length > 0 ? "no matches" : "type to search"
                    color: theme.surface1
                    font.pixelSize: theme.fontSize
                    font.family: theme.font
                }
            }

            // footer — mode badge + hints
            RowLayout {
                Layout.fillWidth: true

                // mode badge
                Rectangle {
                    width: 26
                    height: 20
                    radius: 4
                    color: root.searchMode ? theme.green : theme.lavender
                    Layout.leftMargin: 4

                    Text {
                        anchors.centerIn: parent
                        text: root.searchMode ? "I" : "N"
                        color: theme.base
                        font.bold: true
                        font.pixelSize: 11
                        font.family: theme.font
                    }
                }

                Text {
                    text: root.searchMode ? "INSERT" : "NORMAL"
                    color: root.searchMode ? theme.green : theme.lavender
                    font.pixelSize: theme.fontSize - 1
                    font.family: theme.font
                    font.bold: true
                    Layout.leftMargin: 6
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.searchMode
                        ? "↑↓ nav · ↵ launch · esc exit"
                        : "j/k nav · / search · ↵ launch · esc close"
                    color: theme.surface1
                    font.pixelSize: theme.fontSize - 1
                    font.family: theme.font
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
