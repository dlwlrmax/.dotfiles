import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.common
import "TodoLogic.js" as T

// Todo panel: list + add bar, or (after clicking an item) a detail view with the
// full title / due / note as selectable text and one-click copy buttons.
Item {
    id: root
    property Theme theme: ThemeStore
    property bool active: false
    property var dataSource: null      // DataProviders.todoData
    signal close()

    readonly property var items: dataSource ? dataSource.items : []
    readonly property int nowKey: dataSource ? dataSource.nowKey : 0
    readonly property int nowMinutes: dataSource ? dataSource.nowMinutes : 0

    // Id of the todo shown in the detail view, 0 = list view. The row is looked up
    // live so toggling done / external edits are reflected; a deleted row closes it.
    property int detailId: 0
    readonly property var detail: {
        if (detailId === 0) return null
        for (var i = 0; i < items.length; i++) if (items[i].id === detailId) return items[i]
        return null
    }
    onDetailChanged: if (detailId !== 0 && detail === null) detailId = 0

    // Capped to the screen under the bar; the list scrolls beyond that.
    readonly property real maxHeight: {
        var scr = root.QsWindow.window ? root.QsWindow.window.screen : null
        return Math.min(880, scr ? scr.height - theme.barHeight - 24 : 880)
    }

    focus: true
    // Escape steps back out of the detail view first, then closes the panel.
    Keys.onEscapePressed: {
        if (detailId !== 0) { detailId = 0; Qt.callLater(function () { addBar.focusTitle() }) }
        else root.close()
    }

    clip: true
    implicitWidth: theme.panelWidthM
    implicitHeight: Math.min(maxHeight, Math.max(220, content.implicitHeight + 2 * theme.panelMargin))

    // Always reopen on the list; when opening also scroll to the top and focus the title.
    onActiveChanged: {
        detailId = 0
        if (active) {
            list.positionViewAtBeginning()
            Qt.callLater(function () { addBar.focusTitle() })
        }
    }

    // ── copy-to-clipboard feedback ──
    // "title" | "note" | "all" | "" — which copy button just fired. Reset when the
    // shown todo changes so the check never carries over to another item.
    property string copied: ""
    onDetailIdChanged: { copied = ""; copyTimer.stop() }

    function copyText(what, text) {
        if (text === "") return
        Quickshell.execDetached(["wl-copy", "--", text])
        copied = what
        copyTimer.restart()
    }

    Timer {
        id: copyTimer
        interval: 1500
        onTriggered: root.copied = ""
    }

    PanelBackground {
        anchors.fill: parent
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: theme.panelMargin
        spacing: 10

        // ════════ list view ════════
        PanelHeader {
            visible: root.detailId === 0
            theme: root.theme
            title: "Todo"
            onClose: root.close()

            Badge {
                theme: root.theme
                text: root.dataSource ? root.dataSource.pendingCount : 0
                clr: root.dataSource && root.dataSource.overdueCount > 0 ? theme.red : theme.subtext0
            }
        }

        Item {
            visible: root.detailId === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            implicitHeight: list.contentHeight

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: root.items

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: TodoRow {
                    required property var modelData
                    width: ListView.view.width
                    todo: modelData
                    theme: root.theme
                    nowKey: root.nowKey
                    nowMinutes: root.nowMinutes
                    onToggled: root.dataSource.toggle(modelData.id)
                    onRemoved: root.dataSource.remove(modelData.id)
                    onOpened: { root.detailId = modelData.id; root.forceActiveFocus() }
                }
            }

            // Sibling of the ListView (not a child: a Flickable reparents children into
            // its contentItem, which is 0 high when empty).
            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "Nothing to do"
                color: theme.subtext0
                font.pixelSize: theme.fontSize
                font.family: theme.fontUi
            }
        }

        TodoAddBar {
            id: addBar
            visible: root.detailId === 0
            Layout.fillWidth: true
            theme: root.theme
            todayKey: root.nowKey
            nowMinutes: root.nowMinutes
            onSubmitted: (title, content, dueKey, dueMinutes) => {
                if (root.dataSource) root.dataSource.add(title, content, dueKey, dueMinutes)
            }
        }

        // ════════ detail view ════════
        RowLayout {
            visible: root.detailId !== 0
            Layout.fillWidth: true
            spacing: 8

            IconButton {
                theme: root.theme
                text: Glyphs.prev
                onClicked: root.detailId = 0
            }

            Text {
                text: "Detail"
                color: theme.text
                font.pixelSize: theme.fontSize + 1
                font.bold: true
                font.family: theme.font
            }

            Item { Layout.fillWidth: true }

            // Status / due badge.
            Badge {
                visible: root.detail !== null
                theme: root.theme
                text: {
                    var t = root.detail
                    if (!t) return ""
                    if (t.done) return "Done"
                    var d = T.formatDue(t, root.nowKey)
                    return d === "" ? "No due" : d
                }
                clr: {
                    var t = root.detail
                    if (!t || t.done) return theme.overlay1
                    if (T.isOverdue(t, root.nowKey, root.nowMinutes)) return theme.red
                    if (T.isDated(t) && t.due_key === root.nowKey) return theme.highlight
                    return theme.subtext0
                }
            }

            IconButton {
                theme: root.theme
                text: Glyphs.close
                onClicked: root.close()
            }
        }

        // Title: full text, wraps, selectable; copy button alongside.
        Rectangle {
            visible: root.detailId !== 0
            Layout.fillWidth: true
            implicitHeight: titleRow.implicitHeight + 16
            radius: theme.radiusMd
            color: theme.surface0

            RowLayout {
                id: titleRow
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                TextEdit {
                    Layout.fillWidth: true
                    text: root.detail ? root.detail.title : ""
                    textFormat: TextEdit.PlainText
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: root.detail && root.detail.done ? theme.overlay1 : theme.text
                    selectionColor: theme.highlight
                    selectedTextColor: theme.base
                    font.pixelSize: theme.fontSize + 1
                    font.bold: true
                    font.strikeout: !!(root.detail && root.detail.done)
                    font.family: theme.fontUi
                }

                IconButton {
                    theme: root.theme
                    text: root.copied === "title" ? Glyphs.check : Glyphs.copy
                    tint: root.copied === "title" ? theme.green : "transparent"
                    glyphSize: theme.fontSizeMin
                    Layout.alignment: Qt.AlignTop
                    onClicked: root.copyText("title", root.detail ? root.detail.title : "")
                }
            }
        }

        // Note: scrollable, selectable; copy button in the corner.
        Rectangle {
            id: noteBox
            visible: root.detailId !== 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            implicitHeight: Math.min(Math.max(noteEdit.implicitHeight + 16, 80), 420)
            radius: theme.radiusMd
            color: theme.surface0

            readonly property string note: root.detail ? String(root.detail.content || "") : ""

            Flickable {
                id: noteFlick
                anchors.fill: parent
                anchors.margins: 8
                anchors.rightMargin: 36
                contentWidth: width
                contentHeight: noteEdit.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                TextEdit {
                    id: noteEdit
                    width: noteFlick.width
                    text: noteBox.note !== "" ? noteBox.note : "No note"
                    textFormat: TextEdit.PlainText
                    readOnly: true
                    selectByMouse: noteBox.note !== ""
                    wrapMode: TextEdit.Wrap
                    color: noteBox.note !== "" ? theme.subtext1 : theme.overlay0
                    font.italic: noteBox.note === ""
                    selectionColor: theme.highlight
                    selectedTextColor: theme.base
                    font.pixelSize: theme.fontSize
                    font.family: theme.fontUi
                }
            }

            IconButton {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8
                theme: root.theme
                text: root.copied === "note" ? Glyphs.check : Glyphs.copy
                tint: root.copied === "note" ? theme.green : "transparent"
                glyphSize: theme.fontSizeMin
                enabled: noteBox.note !== ""
                onClicked: root.copyText("note", noteBox.note)
            }
        }

        // Actions: done toggle, copy both, delete.
        RowLayout {
            visible: root.detailId !== 0
            Layout.fillWidth: true
            spacing: 6

            Badge {
                theme: root.theme
                text: root.detail && root.detail.done ? "Mark undone" : "Mark done"
                clickable: true
                solid: !!(root.detail && root.detail.done)
                clr: root.detail && root.detail.done ? theme.overlay1 : theme.green
                implicitHeight: 24
                onClicked: if (root.detail) root.dataSource.toggle(root.detail.id)
            }

            Badge {
                theme: root.theme
                text: root.copied === "all" ? "Copied ✓" : "Copy all"
                clickable: true
                clr: root.copied === "all" ? theme.green : theme.subtext0
                implicitHeight: 24
                onClicked: {
                    var t = root.detail
                    if (!t) return
                    var note = String(t.content || "")
                    root.copyText("all", note !== "" ? t.title + "\n\n" + note : t.title)
                }
            }

            Item { Layout.fillWidth: true }

            Badge {
                theme: root.theme
                text: "Delete"
                clickable: true
                clr: theme.red
                implicitHeight: 24
                onClicked: {
                    var id = root.detailId
                    root.detailId = 0
                    if (id !== 0) root.dataSource.remove(id)
                }
            }
        }
    }
}
