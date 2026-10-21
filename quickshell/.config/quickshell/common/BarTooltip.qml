import Quickshell
import QtQuick
import QtQuick.Layouts

// Themed hover tooltip. A separate popup window, so it isn't clipped by the
// bar's short layer-shell surface or a panel's bounds. The window only exists
// while hovered, so it's cheap to put in list delegates.
//   BarTooltip { target: item; hovered: area.containsMouse; text: "..." }
//   BarTooltip { target: item; hovered: hover.hovered; Text { ... } }   // custom content
// Non-visual: place it anywhere except directly in a Layout.
Item {
    id: tip
    required property Item target
    property Theme theme: ThemeStore
    property bool hovered: false
    // Caller sets on click so the tooltip doesn't cover the action; cleared on hover exit.
    property bool suppressed: false
    property int delay: 400
    property string text: ""
    property int textFormat: Text.PlainText
    // Show even on the gaming monitor (e.g. the gaming indicator's own tooltip).
    property bool ignoreQuiet: false
    // True while the popup exists; gate heavy content (previews) on this.
    readonly property bool open: loader.active
    default property alias content: col.data

    property bool _open: false

    visible: false

    function _sync() {
        if (hovered) {
            openDelay.restart()
        } else {
            openDelay.stop()
            _open = false
            suppressed = false
        }
    }
    onHoveredChanged: _sync()
    Component.onCompleted: _sync()

    Timer {
        id: openDelay
        interval: tip.delay
        onTriggered: tip._open = true
    }

    // Lives here while closed; reparented into the popup while it exists.
    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: 4

        Text {
            visible: tip.text !== ""
            text: tip.text
            textFormat: tip.textFormat
            color: tip.theme.text
            font.pixelSize: tip.theme.fontSize - 1
            font.family: tip.theme.font
            wrapMode: Text.Wrap
            Layout.maximumWidth: 360
        }
    }

    LazyLoader {
        id: loader
        active: tip._open && !tip.suppressed && tip.target.visible
                && (tip.ignoreQuiet || !ShellState.quietOn(tip.target.QsWindow.window?.screen?.name ?? ""))

        PopupWindow {
            id: popup
            visible: true
            color: "transparent"
            implicitWidth: box.implicitWidth
            implicitHeight: box.implicitHeight
            // Position is computed in onAnchoring; recompute when the text changes size.
            onImplicitWidthChanged: anchor.updateAnchor()
            onImplicitHeightChanged: anchor.updateAnchor()

            anchor.item: tip.target
            // Slide back on-screen instead of overflowing (rightmost tray icons, etc).
            anchor.adjustment: PopupAdjustment.Slide
            anchor.onAnchoring: {
                var t = tip.target
                var win = t.QsWindow.window
                // In the bar, drop below the bar's bottom edge; in panels, just below the target.
                var inBar = win && win.height <= tip.theme.barHeight
                var y = inBar ? win.height - t.mapToItem(null, 0, 0).y : t.height
                anchor.rect.x = (t.width - box.implicitWidth) / 2
                anchor.rect.y = y + 6
            }

            Rectangle {
                id: box
                implicitWidth: col.implicitWidth + 24
                implicitHeight: col.implicitHeight + 18
                radius: 10
                color: tip.theme.base
                border.color: tip.theme.surface0
                border.width: 1
                opacity: 0

                NumberAnimation on opacity { to: 1; duration: 120; easing.type: Easing.OutCubic }

                Component.onCompleted: col.parent = box
                Component.onDestruction: col.parent = tip
            }
        }
    }
}
