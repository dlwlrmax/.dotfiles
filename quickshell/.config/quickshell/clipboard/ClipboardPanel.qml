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

    implicitWidth: 620
    implicitHeight: 520
    focus: true

    property string query: ""
    property var allEntries: []
    property var filteredEntries: []
    property int selectedIndex: 0

    function loadEntries() {
        if (!loadProc.running) loadProc.running = true
    }

    Process {
        id: loadProc
        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split('\n')
                var entries = []
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i]
                    if (!line) continue
                    var tabIdx = line.indexOf('\t')
                    if (tabIdx < 0) continue
                    var id = line.substring(0, tabIdx)
                    var content = line.substring(tabIdx + 1)
                    content = content.replace(/^---\s+/, '')
                    entries.push({
                        id: id,
                        content: content,
                        isImage: /^\[\s+binary/.test(content)
                    })
                }
                root.allEntries = entries
                root.applyFilter()
            }
        }
    }

    function applyFilter() {
        var q = query.trim().toLowerCase()
        if (!q) {
            root.filteredEntries = root.allEntries.slice(0, 50)
            root.selectedIndex = 0
            return
        }
        var filtered = []
        for (var i = 0; i < root.allEntries.length; i++) {
            var e = root.allEntries[i]
            if (e.content.toLowerCase().indexOf(q) !== -1) {
                filtered.push(e)
            }
        }
        root.filteredEntries = filtered.slice(0, 50)
        root.selectedIndex = 0
    }

    function copyEntry(entry) {
        if (!entry) return
        var cmd = "cliphist decode <<<'" + entry.id + "' | wl-copy"
        copyProc.command = ["bash", "-c", cmd]
        copyProc.running = true
    }

    Process {
        id: copyProc
        onRunningChanged: {
            if (!running) {
                root.close()
            }
        }
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

    function truncate(str, maxLen) {
        if (str.length <= maxLen) return str
        return str.substring(0, maxLen - 1) + '\u2026'
    }

    function previewLine(text) {
        var s = text.replace(/\n/g, ' \u00b7 ')
        return truncate(s, 120)
    }

    onActiveChanged: {
        if (active) {
            query = ""
            selectedIndex = 0
            loadEntries()
            Qt.callLater(function () {
                searchField.forceActiveFocus()
                searchField.focus = true
            })
        }
    }

    onQueryChanged: applyFilter()

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            close(); return
        }
        if (event.key === Qt.Key_Up) { moveSelection(-1); return }
        if (event.key === Qt.Key_Down) { moveSelection(1); return }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (filteredEntries.length > 0)
                copyEntry(filteredEntries[selectedIndex])
            return
        }
        if (event.key === Qt.Key_J) { moveSelection(1); return }
        if (event.key === Qt.Key_K) { moveSelection(-1); return }
        var ch = event.text
        if (ch.length > 0 && ch.charCodeAt(0) >= 32) {
            searchField.focus = true
            searchField.text = ch
            query = ch
        }
    }

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
                border.color: theme.lavender
                border.width: 2

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 8

                    Text {
                        text: "\uf0ea"  // search icon
                        color: theme.subtext0
                        font.family: theme.font
                        font.pixelSize: 16
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        verticalAlignment: TextInput.AlignVCenter
                        background: Item {}
                        color: theme.text
                        font.pixelSize: theme.fontSize + 3
                        font.family: theme.font
                        placeholderText: "Search clipboard history\u2026"
                        placeholderTextColor: theme.surface1
                        text: root.query
                        onTextChanged: root.query = text
                        selectByMouse: true

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (root.filteredEntries.length > 0)
                                    root.copyEntry(root.filteredEntries[root.selectedIndex])
                                return
                            }
                            if (event.key === Qt.Key_Up) { root.moveSelection(-1); return }
                            if (event.key === Qt.Key_Down) { root.moveSelection(1); return }
                            if (event.key === Qt.Key_Escape) { root.close(); return }
                            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_N) {
                                root.moveSelection(1); return
                            }
                            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_P) {
                                root.moveSelection(-1); return
                            }
                        }
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
                    spacing: 4
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
                            spacing: 10

                            Text {
                                text: row.modelData.isImage ? "\uf1c5" : "\uf24d"
                                color: theme.subtext0
                                font.family: theme.font
                                font.pixelSize: 16
                                Layout.preferredWidth: 24
                                horizontalAlignment: Text.AlignHCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    text: root.previewLine(row.modelData.content)
                                    color: theme.text
                                    font.pixelSize: theme.fontSize + 1
                                    font.family: theme.font
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    maximumLineCount: 1
                                }

                                Text {
                                    text: "id: " + row.modelData.id
                                    color: theme.surface1
                                    font.pixelSize: theme.fontSize - 2
                                    font.family: theme.font
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.selectedIndex = row.index
                            onClicked: root.copyEntry(row.modelData)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.filteredEntries.length === 0
                    text: root.allEntries.length === 0
                        ? "loading clipboard history\u2026"
                        : root.query.length > 0
                            ? "no matches"
                            : "clipboard is empty"
                    color: theme.surface1
                    font.pixelSize: theme.fontSize
                    font.family: theme.font
                }
            }

            // footer hints
            Text {
                Layout.fillWidth: true
                text: "\u2191\u2193 nav  \u00b7  \u23ce copy  \u00b7  esc close"
                color: theme.surface1
                font.pixelSize: theme.fontSize - 1
                font.family: theme.font
                horizontalAlignment: Text.AlignHCenter
                Layout.bottomMargin: 4
            }
        }
    }
}
