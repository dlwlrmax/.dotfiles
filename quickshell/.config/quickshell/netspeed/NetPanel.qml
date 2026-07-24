import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property bool active: false
    property var dataSource: null
    signal close()

    // ── Speed data (from dataSource = netData) ──
    property string dlText: dataSource ? dataSource.dlText : "--"
    property string ulText: dataSource ? dataSource.ulText : "--"

    // ── Info data (from net-panel info polling) ──
    property string netIface: ""
    property var netIps: []
    property var currentDns: []
    property var tailscaleData: null  // { active, exit_node, peers[{name, online}] }

    // ── Speed test state ──
    property bool speedTestRunning: false
    property string speedResult: ""

    // ── DNS apply feedback ──
    property string dnsFeedback: ""
    property string dnsAppliedLabel: ""
    property string dnsBin: Quickshell.env("HOME") + "/.cargo/bin/net-panel"

    // ── Hardcoded DNS providers ──
    property var dnsProviders: [
        { id: "cloudflare", label: "Cloudflare", primary: "1.1.1.1", secondary: "1.0.0.1" },
        { id: "google",     label: "Google",     primary: "8.8.8.8", secondary: "8.8.4.4" },
        { id: "quad9",      label: "Quad9",      primary: "9.9.9.9", secondary: "149.112.112.112" },
        { id: "opendns",    label: "OpenDNS",    primary: "208.67.222.222", secondary: "208.67.220.220" },
        { id: "adguard",    label: "AdGuard",    primary: "94.140.14.14", secondary: "94.140.15.15" },
        { id: "nextdns",    label: "NextDNS",    primary: "45.90.28.0", secondary: "45.90.30.0" },
        { id: "mullvad",    label: "Mullvad",    primary: "194.242.2.2", secondary: "194.242.2.3" }
    ]

    function isProviderActive(provider) {
        if (!currentDns || currentDns.length === 0) return false
        for (var i = 0; i < currentDns.length; i++) {
            var ip = currentDns[i].split(':')[0].split('#')[0]
            if (ip === provider.primary || ip === provider.secondary)
                return true
        }
        return false
    }

    clip: true
    implicitWidth: 420
    implicitHeight: 640

    Rectangle {
        anchors.fill: parent
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 16
        bottomRightRadius: 16
        color: theme.color
        border.color: theme.surface0
        border.width: 2

        // mask top border
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: theme.color
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        // ── header ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Network"
                color: theme.text
                font.pixelSize: theme.fontSize + 1
                font.bold: true
                font.family: theme.font
                Layout.fillWidth: true
            }

            Text {
                text: "×"
                color: theme.subtext0
                font.pixelSize: theme.fontSize + 4
                font.family: theme.font

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.surface0
        }

        // ── 1. Speed Section ──
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "  " + root.dlText
                color: theme.text
                font.pixelSize: theme.fontSize
                font.family: theme.font
            }

            Text {
                text: "  " + root.ulText
                color: theme.text
                font.pixelSize: theme.fontSize
                font.family: theme.font
            }
        }

        Text {
            text: root.netIface ? "Interface: " + root.netIface : ""
            color: theme.subtext0
            font.pixelSize: theme.fontSize - 1
            font.family: theme.font
            visible: root.netIface !== ""
        }

        Text {
            text: root.netIps.length > 0 ? "IPs: " + root.netIps.join(", ") : ""
            color: theme.subtext0
            font.pixelSize: theme.fontSize - 1
            font.family: theme.font
            visible: root.netIps.length > 0
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.surface0
        }

        // ── 2. DNS Selector Section ──
        Text {
            text: "DNS"
            color: theme.text
            font.pixelSize: theme.fontSize
            font.bold: true
            font.family: theme.font
        }

        Text {
            text: root.currentDns.length > 0
                ? "Current: " + root.currentDns.join(", ")
                : "Current: --"
            color: theme.subtext1
            font.pixelSize: theme.fontSize - 1
            font.family: theme.font
        }

        // DNS provider buttons in a Flow
        Flow {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: root.dnsProviders

                delegate: Item {
                    // capture modelData before Repeater scope changes
                    property var provider: modelData
                    property bool active: root.isProviderActive(provider)

                    width: labelText.implicitWidth + 16
                    height: labelText.implicitHeight + 8

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: parent.active ? theme.surface0 : "transparent"
                        border.color: parent.active ? theme.blue : theme.surface0
                        border.width: 1
                    }

                    Text {
                        id: labelText
                        anchors.centerIn: parent
                        text: modelData.label
                        color: parent.active ? theme.blue : theme.subtext0
                        font.pixelSize: theme.fontSize - 1
                        font.family: theme.font
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.dnsFeedback = ""
                            root.dnsAppliedLabel = modelData.label
                            dnsSetProc.command = [
                                root.dnsBin, "dns", "set", modelData.id
                            ]
                            dnsSetProc.running = true
                        }
                    }

                    // Feedback indicator
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 3
                        text: root.dnsAppliedLabel === modelData.label ? root.dnsFeedback : ""
                        color: root.dnsFeedback === "✓ Applied" ? theme.green : theme.red
                        font.pixelSize: theme.fontSize - 3
                        font.family: theme.font
                        visible: root.dnsAppliedLabel === modelData.label && root.dnsFeedback !== ""
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.surface0
        }

        // ── 3. Speed Test Section ──
        Text {
            text: "Speed Test"
            color: theme.text
            font.pixelSize: theme.fontSize
            font.bold: true
            font.family: theme.font
        }

        // Button
        Rectangle {
            Layout.preferredWidth: speedBtnText.implicitWidth + 24
            Layout.preferredHeight: speedBtnText.implicitHeight + 12
            Layout.alignment: Qt.AlignLeft
            radius: 6
            color: "transparent"
            border.color: root.speedTestRunning ? theme.surface0 : theme.blue
            border.width: 1

            Text {
                id: speedBtnText
                anchors.centerIn: parent
                text: root.speedTestRunning ? "Testing..." : "Run Speed Test"
                color: root.speedTestRunning ? theme.subtext0 : theme.blue
                font.pixelSize: theme.fontSize
                font.family: theme.font
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: root.speedTestRunning ? Qt.ArrowCursor : Qt.PointingHandCursor
                enabled: !root.speedTestRunning
                onClicked: {
                    root.speedTestRunning = true
                    root.speedResult = ""
                    speedTestProc.command = [
                        root.dnsBin, "speedtest"
                    ]
                    speedTestProc.running = true
                }
            }
        }

        // Speed test results
        Text {
            text: root.speedResult
            color: theme.subtext1
            font.pixelSize: theme.fontSize - 1
            font.family: theme.font
            visible: root.speedResult !== ""
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.surface0
        }

        // ── 4. Tailscale Section ──
        Text {
            text: "Tailscale"
            color: theme.text
            font.pixelSize: theme.fontSize
            font.bold: true
            font.family: theme.font
        }

        // Tailscale inactive
        Text {
            text: "Tailscale not available"
            color: theme.subtext0
            font.pixelSize: theme.fontSize - 1
            font.family: theme.font
            visible: !root.tailscaleData || !root.tailscaleData.active
        }

        // Tailscale active content
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: root.tailscaleData && root.tailscaleData.active

            Text {
                text: "Exit Node: " + (root.tailscaleData.exit_node || "No exit node")
                color: theme.subtext1
                font.pixelSize: theme.fontSize - 1
                font.family: theme.font
            }

            Text {
                text: "Peers:"
                color: theme.subtext0
                font.pixelSize: theme.fontSize - 1
                font.family: theme.font
                font.bold: true
                visible: root.tailscaleData &&
                    root.tailscaleData.peers &&
                    root.tailscaleData.peers.length > 0
            }

            // Peer list using Column + Repeater
            Column {
                Layout.fillWidth: true
                spacing: 3
                visible: root.tailscaleData &&
                    root.tailscaleData.peers &&
                    root.tailscaleData.peers.length > 0

                Repeater {
                    model: root.tailscaleData ? (root.tailscaleData.peers || []) : []

                    delegate: RowLayout {
                        width: parent.width
                        spacing: 4
                        property var peer: modelData

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: peer.online ? theme.green : theme.red
                        }

                        Text {
                            text: peer.name
                            color: theme.subtext1
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: peer.online ? "online" : "offline"
                            color: peer.online ? theme.green : theme.subtext0
                            font.pixelSize: theme.fontSize - 2
                            font.family: theme.font
                        }
                    }
                }
            }
        }
    }

    // ── Info polling: net-panel info every 5s ──
    Process {
        id: infoProc
        command: [root.dnsBin, "info"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim())
                    root.netIface = data.iface || ""
                    root.netIps = data.ips || []
                    root.currentDns = data.dns_servers || []
                    root.tailscaleData = data.tailscale || null
                } catch (e) {
                    console.log("NetPanel: failed to parse info:", e)
                }
            }
        }
    }

    Timer {
        id: pollTimer
        interval: 5000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!infoProc.running) infoProc.running = true
        }
    }

    // ── DNS set process ──
    Process {
        id: dnsSetProc
        running: false

        stdout: StdioCollector {}

        onRunningChanged: {
            if (!running && command.length > 0) {
                root.dnsFeedback = "✓ Applied"
            }
        }
    }

    // ── Speed test process ──
    Process {
        id: speedTestProc
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.speedTestRunning = false
                var output = this.text.trim()
                if (!output) {
                    root.speedResult = "No results"
                    return
                }
                try {
                    var data = JSON.parse(output)
                    var parts = []
                    if (data.download_mbps) parts.push("↓ " + data.download_mbps + " Mbps")
                    if (data.upload_mbps)   parts.push("↑ " + data.upload_mbps + " Mbps")
                    if (data.ping_ms)       parts.push("⏱ " + data.ping_ms + " ms")
                    if (data.server_name)   parts.push("📡 " + data.server_name)
                    root.speedResult = parts.length > 0 ? parts.join("  ") : output
                } catch (e) {
                    // plain-text output (not JSON)
                    root.speedResult = output
                }
            }
        }

        onRunningChanged: {
            if (!running && !root.speedResult) {
                root.speedTestRunning = false
                root.speedResult = "No results"
            }
        }
    }
}
