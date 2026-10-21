import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: ThemeStore
    property var dataSource: null
    property string dlText: dataSource ? dataSource.dlText : "--"
    property string ulText: dataSource ? dataSource.ulText : "--"
    readonly property bool connected: dataSource ? dataSource.connected : false
    // A direction is tinted once it moves more than theme.netActiveBps.
    readonly property bool dlActive: connected && dataSource.dlBps > theme.netActiveBps
    readonly property bool ulActive: connected && dataSource.ulBps > theme.netActiveBps
    signal togglePanel()

    // Width only ever grows, so the bar doesn't jitter as "9.9K" becomes "10.0K".
    property int widest: 50
    readonly property int wanted: iconW + 2 + Math.max(dlVal.implicitWidth, ulVal.implicitWidth)
    readonly property int iconW: 12
    onWantedChanged: if (wanted > widest) widest = wanted

    // Hard containment: layout squeeze must never paint over neighbors.
    clip: true
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    Column {
        id: col
        spacing: 0
        width: root.widest
        opacity: root.connected ? 1 : 0.5

        RowLayout {
            spacing: 2
            width: parent.width

            Text {
                text: ""
                color: root.dlActive ? root.theme.blue : root.theme.subtext0
                font.pixelSize: root.theme.fontSize
                font.family: root.theme.font
                font.weight: Font.Medium
                Layout.preferredWidth: root.iconW
            }

            Text {
                id: dlVal
                text: root.dlText
                color: root.dlActive ? root.theme.blue : root.theme.subtext0
                font.pixelSize: root.theme.fontSize - 2
                font.family: root.theme.font
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight
                Layout.fillWidth: true
            }
        }

        RowLayout {
            spacing: 2
            width: parent.width

            Text {
                text: ""
                color: root.ulActive ? root.theme.peach : root.theme.subtext0
                font.pixelSize: root.theme.fontSize
                font.family: root.theme.font
                font.weight: Font.Medium
                Layout.preferredWidth: root.iconW
            }

            Text {
                id: ulVal
                text: root.ulText
                color: root.ulActive ? root.theme.peach : root.theme.subtext0
                font.pixelSize: root.theme.fontSize - 2
                font.family: root.theme.font
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight
                Layout.fillWidth: true
            }
        }
    }

    // ── Hover tooltip: interface, IP and DNS (fetched on demand, not polled) ──
    property string tipIface: ""
    property var tipIps: []
    property var tipDns: []

    readonly property string tipText: {
        if (!connected) return "Offline"
        var lines = []
        if (tipIface) lines.push(tipIface + (tipIps.length ? " · " + tipIps.join(", ") : ""))
        lines.push(" " + dlText + "/s    " + ulText + "/s")
        if (tipDns.length) lines.push("DNS " + tipDns.join(", "))
        return lines.join("\n")
    }

    BarTooltip {
        target: root
        theme: root.theme
        hovered: ma.containsMouse
        text: root.tipText
    }

    Process {
        id: tipProc
        command: [root.theme.scriptDir + "/net-panel.sh", "info"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim())
                    root.tipIface = data.iface || ""
                    root.tipIps = data.ips || []
                    root.tipDns = data.dns_servers || []
                } catch (e) {
                    // keep the previous tooltip contents
                }
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: if (containsMouse && !tipProc.running) tipProc.running = true
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.togglePanel()
            }
        }
    }
}
