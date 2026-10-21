import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

// Bar indicator: phone glyph (red dot = unread), battery of the reachable
// device with the lowest charge, "+N" when several are connected. Left click
// opens the panel, right click rings the phone.
Item {
    id: root
    property Theme theme: ThemeStore
    property var dataSource: null
    signal togglePanel(int centerX)

    readonly property var allDevices: dataSource ? dataSource.devices : []
    readonly property var connected: allDevices.filter(function (d) { return d.paired !== false && d.reachable })
    property bool anyConnected: dataSource ? dataSource.anyConnected : false

    // Lowest battery among connected devices; falls back to the first known device.
    readonly property var device: {
        var pool = connected.length > 0 ? connected : allDevices
        var best = null
        for (var i = 0; i < pool.length; i++) {
            var b = pool[i].battery
            if (best === null || (b !== null && b >= 0 && (best.battery === null || best.battery < 0 || b < best.battery)))
                best = pool[i]
        }
        return best
    }
    readonly property int unread: allDevices.reduce(function (n, d) { return n + (d.notifCount || 0) }, 0)
    readonly property bool low: !!device && device.battery !== null && device.battery >= 0
                                && device.battery < 15 && !device.charging

    function batteryColor(b) {
        if (b === null || b === undefined || b < 0) return theme.text
        if (b < 20) return theme.red
        if (b < 50) return theme.yellow
        return theme.green
    }

    function tipLines() {
        if (allDevices.length === 0) return "KDE Connect: no devices"
        var out = []
        for (var i = 0; i < allDevices.length; i++) {
            var d = allDevices[i]
            var s = d.name || "Device"
            if (d.paired === false) s += " (not paired)"
            else if (!d.reachable) s += " (offline)"
            else {
                if (d.battery !== null && d.battery >= 0) s += " — " + d.battery + "%" + (d.charging ? " charging" : "")
                if (d.networkType) s += " · " + d.networkType
                if (d.notifCount > 0) s += " · " + d.notifCount + " notifications"
            }
            out.push(s)
        }
        out.push("Right-click to ring the phone")
        return out.join("\n")
    }

    // Hard containment: layout squeeze must never paint over neighbors.
    clip: true
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight + 6.5
    Layout.alignment: Qt.AlignVCenter
    visible: Prefs.show("phone")
    opacity: anyConnected ? 1 : 0.35

    RowLayout {
        id: row
        y: 4
        spacing: 4

        Item {
            implicitWidth: iconText.implicitWidth + 6
            implicitHeight: iconText.implicitHeight + 4

            Text {
                id: iconText
                anchors.centerIn: parent
                text: ""  // phone icon
                color: theme.text
                font.pixelSize: theme.fontSize + 4
                font.weight: Font.Medium
                font.family: theme.font
            }

            // Unread marker: a small dot; counts are in the tooltip.
            Rectangle {
                visible: root.unread > 0
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 2
                anchors.rightMargin: 1
                width: 8
                height: 8
                radius: 4
                color: theme.red
                border.width: 1
                border.color: theme.capsuleColor
            }
        }

        Text {
            id: batteryText
            visible: root.device && root.anyConnected
            text: (root.device && root.device.charging ? "" : "")
                  + (root.device && root.device.battery !== null && root.device.battery >= 0
                     ? root.device.battery + "%" : "--")
            color: root.device ? root.batteryColor(root.device.battery) : theme.text
            font.pixelSize: theme.fontSize - 1
            font.weight: Font.Medium
            font.family: theme.font

            // Pulse while critically low and not charging.
            SequentialAnimation on opacity {
                running: root.low
                loops: Animation.Infinite
                onRunningChanged: if (!running) batteryText.opacity = 1
                NumberAnimation { to: 0.35; duration: 700 }
                NumberAnimation { to: 1; duration: 700 }
            }
        }

        Text {
            visible: root.connected.length > 1
            text: "+" + (root.connected.length - 1)
            color: theme.subtext0
            font.pixelSize: theme.fontSizeMin
            font.family: theme.font
        }
    }

    BarTooltip {
        target: root
        theme: root.theme
        hovered: clickArea.containsMouse
        text: root.tipLines()
    }

    Process {
        id: ringProc
        running: false
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                var target = root.connected.length > 0 ? root.connected[0] : null
                if (target && !ringProc.running) {
                    ringProc.command = ["kdeconnect-cli", "-d", target.id, "--ring"]
                    ringProc.running = true
                }
                return
            }
            var win = root.window
            var p = root.mapToItem(win ? win.contentItem : null, 0, 0)
            root.togglePanel(p.x + root.width / 2)
        }
    }
}
