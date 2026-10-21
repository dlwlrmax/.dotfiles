import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Centered "search and pick" panel shared by the launcher and the clipboard
// history: search field, scrolling result list (optional section headers),
// optional preview pane, footer hints, and ONE keyboard handler.
//
// The parent filters: watch `query`, build `rows`, react to the signals.
// Row fields (all optional except title):
//   isHeader/label            section header (skipped by navigation)
//   title | titleHtml         main text (titleHtml is rich text)
//   subtitle                  second line
//   glyph, glyphClr           Nerd Font icon
//   icon: {appId, name, fallbackGlyph}   application icon
//   thumb                     image file path (shown instead of an icon)
//   tag                       small right-aligned text
//
// Keys: ↑/↓ Ctrl+P/N PgUp/PgDn move · Enter activate · Shift+Enter activate
// (alternate) · Tab or → at end secondary · Ctrl+D delete (Ctrl+Shift+D: all)
// · Ctrl+S mark · Esc back/close. `modal` adds vim-style normal mode
// (j/k, / or i to type, Ctrl+C or jj to leave insert).
Item {
    id: picker

    property Theme theme: ThemeStore
    property bool active: false
    property string placeholder: "Search…"
    property bool modal: false
    property bool searchMode: true          // insert mode (always true unless modal)
    property string query: ""
    property var rows: []
    property int selectedIndex: 0
    property int rowHeight: 48
    property int iconSize: 28
    property string hints: ""
    property string status: ""              // footer right, e.g. "12 / 146"
    property string emptyText: "no matches"
    property bool canGoBack: false          // Esc emits backRequested() instead of closing
    property Component preview: null
    property real listWidth: 620
    property real previewWidth: 300
    readonly property var current: rows.length > 0 && selectedIndex >= 0 && selectedIndex < rows.length
                                   ? rows[selectedIndex] : null
    readonly property bool previewing: preview !== null && current !== null && !current.isHeader

    signal activated(var row, bool alt)
    signal secondary(var row)
    signal deleteRequested(var row, bool all)
    signal markRequested(var row)
    signal backRequested()
    signal closeRequested()

    implicitWidth: listWidth + (preview !== null ? previewWidth + 10 : 0) + 24
    implicitHeight: 520
    focus: true

    function focusSearch() {
        field.forceActiveFocus()
    }

    function selectFirst() {
        for (var i = 0; i < rows.length; i++) {
            if (!rows[i].isHeader) { selectedIndex = i; return }
        }
        selectedIndex = 0
    }

    function ensureVisible() {
        if (selectedIndex > 0 && rows[selectedIndex - 1] && rows[selectedIndex - 1].isHeader)
            list.positionViewAtIndex(selectedIndex - 1, ListView.Contain)
        list.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    function move(delta) {
        var n = rows.length
        if (n === 0) return
        var i = selectedIndex, guard = n
        do {
            i = ((i + delta) % n + n) % n
        } while (rows[i].isHeader && --guard > 0)
        selectedIndex = i
        ensureVisible()
    }

    // Returns true when the key was consumed. `inField`: focus is in the text field.
    function handleKey(event, inField) {
        var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        var shift = (event.modifiers & Qt.ShiftModifier) !== 0
        var typing = !modal || searchMode      // letters go to the field

        switch (event.key) {
        case Qt.Key_Escape:
            if (canGoBack) backRequested(); else closeRequested()
            return true
        case Qt.Key_Up:       move(-1); return true
        case Qt.Key_Down:     move(1); return true
        case Qt.Key_PageUp:   move(-8); return true
        case Qt.Key_PageDown: move(8); return true
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (current && !current.isHeader) activated(current, shift)
            return true
        case Qt.Key_Tab:
            if (current && !current.isHeader) secondary(current)
            return true
        case Qt.Key_Right:
            if (inField && field.cursorPosition < field.text.length) return false
            if (current && !current.isHeader) { secondary(current); return true }
            return false
        case Qt.Key_Left:
            if (canGoBack && (!inField || field.cursorPosition === 0)) { backRequested(); return true }
            return false
        }

        if (ctrl && event.key === Qt.Key_P) { move(-1); return true }
        if (ctrl && event.key === Qt.Key_N) { move(1); return true }
        if (ctrl && event.key === Qt.Key_D) {
            if (current && !current.isHeader) deleteRequested(current, shift)
            else if (shift) deleteRequested(null, true)
            return true
        }
        if (ctrl && event.key === Qt.Key_S) {
            if (current && !current.isHeader) markRequested(current)
            return true
        }

        if (modal && !searchMode) {
            if (event.key === Qt.Key_J) { move(1); return true }
            if (event.key === Qt.Key_K) { move(-1); return true }
            if (event.key === Qt.Key_Slash || event.key === Qt.Key_I) { searchMode = true; return true }
            var ch = event.text
            if (ch.length > 0 && ch.charCodeAt(0) >= 32 && !ctrl) {
                searchMode = true
                query = ch
                return true
            }
            return true   // swallow everything else in normal mode
        }

        // Typing with focus outside the field (non-modal): redirect into it.
        if (!inField && typing) {
            var t = event.text
            if (t.length > 0 && t.charCodeAt(0) >= 32 && !ctrl) {
                field.forceActiveFocus()
                field.text = field.text + t
                field.cursorPosition = field.text.length
                picker.query = field.text
                return true
            }
        }
        return false
    }

    onSearchModeChanged: {
        if (!modal) return
        if (searchMode) field.forceActiveFocus()
        else picker.forceActiveFocus()
    }

    // Identity of a row, so async refreshes keep the cursor on the same item.
    function keyOf(r) {
        if (!r) return ""
        if (r.isHeader) return "h:" + r.label
        if (r.action) return "a:" + r.action.id
        if (r.entry) return r.kind + ":" + (r.entry.id !== undefined ? r.entry.id : r.entry.name)
        if (r.pin) return "p:" + r.pin.key
        if (r.address) return "w:" + r.address
        return r.kind + ":" + r.title
    }

    property string _selKey: ""
    property string _rowsQuery: ""

    // A new query starts at the top; a refresh with the same query (late results, timers,
    // thumbnails arriving) keeps the selection where the user put it.
    onRowsChanged: {
        var sameQuery = query === _rowsQuery
        _rowsQuery = query
        if (sameQuery && _selKey !== "") {
            for (var i = 0; i < rows.length; i++) {
                if (!rows[i].isHeader && keyOf(rows[i]) === _selKey) { selectedIndex = i; return }
            }
        }
        selectFirst()
    }

    onSelectedIndexChanged: _selKey = keyOf(selectedIndex >= 0 && selectedIndex < rows.length ? rows[selectedIndex] : null)

    // Forget the remembered selection: the next row refresh starts at the top.
    function reset() { _selKey = ""; _rowsQuery = "\u0000" }

    Keys.onPressed: event => { event.accepted = handleKey(event, false) }

    Rectangle {
        anchors.fill: parent
        radius: theme.radiusXl
        // Opaque: busy windows behind a centered overlay would bleed through the 95% colour.
        color: theme.panelColorSolid
        border.color: theme.surface1
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // ── search ──
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                radius: theme.radiusLg
                color: theme.mantle
                border.color: picker.modal && picker.searchMode ? theme.green : theme.highlight
                border.width: picker.modal && picker.searchMode ? 1 : 2

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 8

                    Text {
                        text: ""
                        color: theme.subtext0
                        font.family: theme.font
                        font.pixelSize: theme.iconSize
                    }

                    TextField {
                        id: field
                        Layout.fillWidth: true
                        verticalAlignment: TextInput.AlignVCenter
                        background: Item {}
                        color: theme.text
                        font.pixelSize: theme.fontSize + 3
                        font.family: theme.fontUi
                        placeholderText: picker.modal && !picker.searchMode ? "press / to search" : picker.placeholder
                        placeholderTextColor: theme.overlay0
                        selectByMouse: true
                        readOnly: picker.modal && !picker.searchMode
                        text: picker.query
                        onTextEdited: picker.query = text

                        property bool _lastWasJ: false
                        Timer { id: jjReset; interval: 250; onTriggered: field._lastWasJ = false }

                        Keys.onPressed: event => {
                            if (picker.handleKey(event, true)) { event.accepted = true; return }
                            var ctrl = (event.modifiers & Qt.ControlModifier) !== 0

                            // readline-style editing
                            if (ctrl && event.key === Qt.Key_A) { event.accepted = true; cursorPosition = 0; return }
                            if (ctrl && event.key === Qt.Key_E) { event.accepted = true; cursorPosition = text.length; return }
                            if (ctrl && event.key === Qt.Key_W) {
                                event.accepted = true
                                if (selectionStart !== selectionEnd) { remove(selectionStart, selectionEnd) }
                                else {
                                    var pos = cursorPosition, end = pos
                                    while (end > 0 && text[end - 1] === " ") end--
                                    var start = end
                                    while (start > 0 && text[start - 1] !== " ") start--
                                    remove(start, pos)
                                }
                                picker.query = text
                                return
                            }

                            if (picker.modal) {
                                if (ctrl && event.key === Qt.Key_C) { event.accepted = true; picker.searchMode = false; return }
                                // jj (quick) → normal mode, dropping the first j
                                if (event.key === Qt.Key_J && !ctrl) {
                                    if (_lastWasJ) {
                                        _lastWasJ = false
                                        jjReset.stop()
                                        picker.query = picker.query.slice(0, -1)
                                        picker.searchMode = false
                                        event.accepted = true
                                        return
                                    }
                                    _lastWasJ = true
                                    jjReset.restart()
                                    return
                                }
                                _lastWasJ = false
                            }
                        }
                    }
                }
            }

            // ── results (+ preview) ──
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: list
                        anchors.fill: parent
                        clip: true
                        spacing: 2
                        model: picker.rows
                        boundsBehavior: Flickable.StopAtBounds
                        visible: picker.rows.length > 0

                        delegate: Item {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool header: !!modelData.isHeader
                            readonly property bool selected: index === picker.selectedIndex
                            width: list.width
                            height: header ? 28 : picker.rowHeight

                            Text {
                                visible: row.header
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 3
                                text: (row.modelData.label || "").toUpperCase()
                                color: picker.theme.overlay0
                                font.pixelSize: picker.theme.fontSizeMin
                                font.bold: true
                                font.letterSpacing: 1
                                font.family: picker.theme.fontUi
                            }

                            Rectangle {
                                visible: !row.header
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: picker.theme.radiusMd
                                color: row.selected ? picker.theme.surface0 : "transparent"
                            }

                            RowLayout {
                                visible: !row.header
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                // icon slot: thumbnail, app icon or glyph
                                Item {
                                    Layout.preferredWidth: picker.iconSize + 4
                                    Layout.preferredHeight: picker.iconSize + 4
                                    Layout.alignment: Qt.AlignVCenter

                                    Image {
                                        id: thumb
                                        anchors.fill: parent
                                        visible: !!row.modelData.thumb && status === Image.Ready
                                        source: row.modelData.thumb ? "file://" + row.modelData.thumb : ""
                                        sourceSize.width: 96
                                        sourceSize.height: 96
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        smooth: true
                                        mipmap: true
                                    }

                                    AppIcon {
                                        anchors.centerIn: parent
                                        visible: !!row.modelData.icon && !thumb.visible
                                        appId: row.modelData.icon ? row.modelData.icon.appId || "" : ""
                                        iconName: row.modelData.icon ? row.modelData.icon.name || "" : ""
                                        fallbackGlyph: row.modelData.icon ? row.modelData.icon.fallbackGlyph || "󰔬" : ""
                                        fallbackIcon: "application-x-executable"
                                        size: picker.iconSize
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !!row.modelData.glyph && !row.modelData.icon && !thumb.visible
                                        text: row.modelData.glyph || ""
                                        color: row.modelData.glyphClr || picker.theme.subtext0
                                        font.family: picker.theme.font
                                        font.pixelSize: picker.iconSize - 6
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 0

                                    Text {
                                        Layout.fillWidth: true
                                        textFormat: row.modelData.titleHtml ? Text.RichText : Text.PlainText
                                        text: row.modelData.titleHtml || row.modelData.title || ""
                                        color: picker.theme.text
                                        font.pixelSize: picker.theme.fontSize + 1
                                        font.family: picker.theme.fontUi
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: !!row.modelData.subtitle
                                        text: row.modelData.subtitle || ""
                                        color: picker.theme.subtext0
                                        font.pixelSize: picker.theme.fontSizeMin
                                        font.family: picker.theme.fontUi
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                }

                                Text {
                                    visible: !!row.modelData.tag
                                    text: row.modelData.tag || ""
                                    color: picker.theme.overlay0
                                    font.pixelSize: picker.theme.fontSizeMin
                                    font.family: picker.theme.font
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !row.header
                                hoverEnabled: true
                                // Only real pointer movement moves the selection, so a list
                                // that scrolls under a resting mouse doesn't steal it.
                                onPositionChanged: if (!row.selected) picker.selectedIndex = row.index
                                onClicked: picker.activated(row.modelData, false)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: picker.rows.length === 0
                        text: picker.emptyText
                        color: picker.theme.overlay0
                        font.pixelSize: picker.theme.fontSize
                        font.family: picker.theme.fontUi
                    }
                }

                Rectangle {
                    visible: picker.preview !== null
                    Layout.preferredWidth: picker.previewWidth
                    Layout.fillHeight: true
                    radius: theme.radiusLg
                    color: theme.mantle

                    Loader {
                        anchors.fill: parent
                        anchors.margins: 10
                        sourceComponent: picker.previewing ? picker.preview : null
                        // The preview item may declare `property var row` to follow the selection.
                        onLoaded: {
                            if (item && item.row !== undefined)
                                item.row = Qt.binding(function () { return picker.current })
                        }
                    }
                }
            }

            // ── footer ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Badge {
                    visible: picker.modal
                    theme: picker.theme
                    text: picker.searchMode ? "INSERT" : "NORMAL"
                    clr: picker.searchMode ? picker.theme.green : picker.theme.lavender
                    solid: true
                    Layout.leftMargin: 2
                }

                Text {
                    text: picker.hints
                    color: picker.theme.overlay0
                    font.pixelSize: picker.theme.fontSizeMin
                    font.family: picker.theme.fontUi
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    visible: picker.status !== ""
                    text: picker.status
                    color: picker.theme.overlay0
                    font.pixelSize: picker.theme.fontSizeMin
                    font.family: picker.theme.font
                    Layout.rightMargin: 4
                }
            }
        }
    }
}
