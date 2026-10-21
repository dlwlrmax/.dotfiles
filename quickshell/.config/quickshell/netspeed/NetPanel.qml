import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: ThemeStore
    property bool active: false
    property var dataSource: null
    signal close()

    // ── Speed data (from dataSource = netData) ──
    readonly property string dlText: dataSource ? dataSource.dlText : "--"
    readonly property string ulText: dataSource ? dataSource.ulText : "--"
    readonly property bool connected: dataSource ? dataSource.connected : false

    // ── Info data (from net-panel info polling) ──
    property string netIface: ""
    property var netIps: []
    property var currentDns: []
    property var tailscaleData: null  // { installed, state, active, exit_node, peers[{name, ip, online}] }

    // ── DNS ──
    property var dnsProviders: []     // [{ name, primary, secondary }] from `net-panel dns list`
    property bool dnsBusy: false
    property string dnsFeedback: ""
    property bool dnsFeedbackOk: false
    property string dnsBin: theme.scriptDir + "/net-panel.sh"
    readonly property string activeProvider: {
        for (var i = 0; i < dnsProviders.length; i++) {
            var p = dnsProviders[i]
            for (var j = 0; j < currentDns.length; j++) {
                var ip = currentDns[j].split(':')[0].split('#')[0]
                if (ip === p.primary || ip === p.secondary) return p.name
            }
        }
        return ""
    }

    // ── Speed test ──
    property bool speedTestRunning: false
    // Serial of the current speed-test run; a result is only used if it belongs to the latest run.
    property int speedRun: 0
    property int speedRunning: -1
    property var speedResult: null    // { down, up, ping, server, at } | { error, at }

    // ── Tailscale (derived) ──
    readonly property int maxPeers: 8
    readonly property string tsState: tailscaleData
        ? (tailscaleData.state || (tailscaleData.active ? "Running" : "Unavailable"))
        : "Unknown"
    readonly property var sortedPeers: {
        var peers = (tailscaleData && tailscaleData.peers) ? tailscaleData.peers.slice() : []
        peers.sort(function (a, b) {
            return (b.online - a.online) || a.name.localeCompare(b.name)
        })
        return peers
    }

    // ── Copy-to-clipboard feedback ──
    property string copied: ""

    function copyText(text) {
        copyProc.command = ["wl-copy", text]
        copyProc.running = true
        copied = text
        copyTimer.restart()
    }

    function refreshInfo() {
        if (infoProc.running) infoProc.rerun = true
        else infoProc.running = true
    }

    function tsStateBadge() {
        switch (tsState) {
        case "Running":      return { text: "connected", clr: theme.green }
        case "Stopped":      return { text: "stopped", clr: theme.yellow }
        case "NeedsLogin":   return { text: "needs login", clr: theme.peach }
        case "NotInstalled": return { text: "not installed", clr: theme.subtext0 }
        case "Unavailable":  return { text: "daemon unavailable", clr: theme.subtext0 }
        default:             return { text: tsState.toLowerCase(), clr: theme.subtext0 }
        }
    }

    clip: true
    implicitWidth: theme.panelWidthM
    implicitHeight: content.implicitHeight + 28

    onActiveChanged: if (active && dnsProviders.length === 0) presetsProc.running = true

    PanelBackground {
        anchors.fill: parent
    }

    ColumnLayout {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: theme.panelMargin
        spacing: 10

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
            }

            Badge {
                theme: root.theme
                text: root.connected ? "online" : "offline"
                clr: root.connected ? theme.green : theme.red
            }

            Item { Layout.fillWidth: true }

            IconButton {
                theme: root.theme
                text: Glyphs.close
                glyphSize: theme.fontSize + 1
                onClicked: root.close()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.surface0
        }

        // ── 1. Traffic ──
        SectionCard {
            theme: root.theme
            title: "Traffic"

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: " " + root.dlText + "/s"
                    color: theme.blue
                    font.pixelSize: theme.fontSize + 2
                    font.bold: true
                    font.family: theme.font
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: " " + root.ulText + "/s"
                    color: theme.peach
                    font.pixelSize: theme.fontSize + 2
                    font.bold: true
                    font.family: theme.font
                }
            }

            RateGraph {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                theme: root.theme
                dl: root.dataSource ? root.dataSource.dlHistory : []
                ul: root.dataSource ? root.dataSource.ulHistory : []
                tick: root.dataSource ? root.dataSource.historyTick : 0
                slots: root.dataSource ? root.dataSource.maxHistory : 60
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6
                visible: root.netIface !== ""

                Badge {
                    theme: root.theme
                    text: root.netIface
                    clr: theme.blue
                }

                Repeater {
                    model: root.netIps

                    Badge {
                        required property string modelData
                        theme: root.theme
                        text: root.copied === modelData ? "copied ✓" : modelData
                        clr: root.copied === modelData ? theme.green : theme.subtext1
                        clickable: true
                        onClicked: root.copyText(modelData)
                    }
                }
            }
        }

        // ── 2. DNS ──
        SectionCard {
            theme: root.theme
            title: "DNS"

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.currentDns

                    Badge {
                        required property string modelData
                        theme: root.theme
                        text: modelData
                        clr: theme.subtext0
                    }
                }

                Text {
                    visible: root.currentDns.length === 0
                    text: "--"
                    color: theme.subtext0
                    font.pixelSize: theme.fontSize - 1
                    font.family: theme.font
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6
                opacity: root.dnsBusy ? 0.5 : 1

                Repeater {
                    model: root.dnsProviders

                    Badge {
                        required property var modelData
                        theme: root.theme
                        text: modelData.name
                        clr: modelData.name === root.activeProvider ? theme.blue : theme.subtext0
                        solid: modelData.name === root.activeProvider
                        pixelSize: theme.fontSize - 1
                        implicitHeight: 24
                        clickable: !root.dnsBusy
                        onClicked: {
                            root.dnsFeedback = ""
                            root.dnsBusy = true
                            dnsSetProc.command = [root.dnsBin, "dns", "set", modelData.name]
                            dnsSetProc.running = true
                        }
                    }
                }

                // back to DHCP/automatic DNS
                Badge {
                    visible: root.dnsProviders.length > 0
                    theme: root.theme
                    text: "Auto"
                    clr: theme.peach
                    pixelSize: theme.fontSize - 1
                    implicitHeight: 24
                    clickable: !root.dnsBusy
                    onClicked: {
                        root.dnsFeedback = ""
                        root.dnsBusy = true
                        dnsSetProc.command = [root.dnsBin, "dns", "reset"]
                        dnsSetProc.running = true
                    }
                }
            }

            Text {
                visible: root.dnsProviders.length === 0
                text: "DNS presets unavailable (net-panel not installed?)"
                color: theme.subtext0
                font.pixelSize: theme.fontSize - 1
                font.family: theme.font
            }

            Badge {
                visible: root.dnsFeedback !== ""
                theme: root.theme
                text: root.dnsFeedback
                clr: root.dnsFeedbackOk ? theme.green : theme.red
                Layout.maximumWidth: parent.width
            }
        }

        // ── 3. Speed test ──
        SectionCard {
            theme: root.theme
            title: "Speed test"

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Badge {
                    theme: root.theme
                    text: root.speedTestRunning ? "Cancel" : "Run speed test"
                    clr: root.speedTestRunning ? theme.red : theme.blue
                    pixelSize: theme.fontSize - 1
                    implicitHeight: 24
                    clickable: true
                    onClicked: {
                        if (root.speedTestRunning) {
                            root.speedRun++                    // orphan the running test's result
                            root.speedTestRunning = false
                            speedTestProc.running = false
                            // net-panel's `timeout` child lives in its own process group and would
                            // keep saturating the link; stop it once net-panel is gone.
                            Quickshell.execDetached(["sh", "-c", "sleep 0.3; pkill -TERM -f '^timeout 25 speedtest'"])
                        } else if (!speedTestProc.running) {
                            root.speedRun++
                            root.speedRunning = root.speedRun
                            root.speedTestRunning = true
                            root.speedResult = null
                            speedTestProc.command = [root.dnsBin, "speedtest"]
                            speedTestProc.running = true
                        }
                    }
                }

                // indeterminate progress while a test runs
                Rectangle {
                    visible: root.speedTestRunning
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    radius: 2
                    color: Qt.alpha(theme.surface1, 0.6)
                    clip: true

                    Rectangle {
                        id: sweep
                        width: parent.width * 0.3
                        height: parent.height
                        radius: 2
                        color: theme.blue

                        SequentialAnimation on x {
                            running: root.speedTestRunning
                            loops: Animation.Infinite
                            NumberAnimation { from: -sweep.width; to: sweep.parent.width; duration: 1100; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                Item { visible: !root.speedTestRunning; Layout.fillWidth: true }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6
                visible: root.speedResult !== null

                Badge {
                    visible: root.speedResult !== null && !!root.speedResult.error
                    theme: root.theme
                    text: root.speedResult && root.speedResult.error ? root.speedResult.error : ""
                    clr: theme.red
                    Layout.maximumWidth: parent.width
                }

                Badge {
                    visible: root.speedResult !== null && root.speedResult.down !== undefined
                    theme: root.theme
                    text: " " + (root.speedResult && root.speedResult.down !== undefined ? root.speedResult.down : "") + " Mbps"
                    clr: theme.green
                }

                Badge {
                    visible: root.speedResult !== null && root.speedResult.up !== undefined
                    theme: root.theme
                    text: " " + (root.speedResult && root.speedResult.up !== undefined ? root.speedResult.up : "") + " Mbps"
                    clr: theme.blue
                }

                Badge {
                    visible: root.speedResult !== null && root.speedResult.ping !== undefined
                    theme: root.theme
                    text: "ping " + (root.speedResult && root.speedResult.ping !== undefined ? root.speedResult.ping : "") + " ms"
                    clr: theme.mauve
                }

                Badge {
                    visible: root.speedResult !== null && !!root.speedResult.server
                    theme: root.theme
                    text: root.speedResult && root.speedResult.server ? root.speedResult.server : ""
                    clr: theme.subtext0
                }

                Badge {
                    visible: root.speedResult !== null
                    theme: root.theme
                    text: "at " + (root.speedResult ? root.speedResult.at : "")
                    clr: theme.subtext0
                }
            }
        }

        // ── 4. Tailscale ──
        SectionCard {
            theme: root.theme
            title: "Tailscale"

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Badge {
                    theme: root.theme
                    text: root.tsStateBadge().text
                    clr: root.tsStateBadge().clr
                    solid: root.tsState === "Running"
                }

                Badge {
                    visible: root.tsState === "Running"
                    theme: root.theme
                    text: root.tailscaleData && root.tailscaleData.exit_node
                          ? "exit: " + root.tailscaleData.exit_node : "no exit node"
                    clr: root.tailscaleData && root.tailscaleData.exit_node ? theme.mauve : theme.subtext0
                }

                Badge {
                    visible: root.tsState === "Running" && root.sortedPeers.length > 0
                    theme: root.theme
                    text: root.sortedPeers.filter(function (p) { return p.online }).length
                          + "/" + root.sortedPeers.length + " online"
                    clr: theme.blue
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                visible: root.tsState === "Running" && root.sortedPeers.length > 0

                Repeater {
                    model: root.sortedPeers.slice(0, root.maxPeers)

                    delegate: RowLayout {
                        id: peerRow
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.preferredWidth: 6
                            Layout.preferredHeight: 6
                            radius: 3
                            color: peerRow.modelData.online ? theme.green : theme.surface1
                        }

                        Text {
                            text: peerRow.modelData.name
                            color: peerRow.modelData.online ? theme.text : theme.subtext0
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.copied === peerRow.modelData.ip ? "copied ✓" : peerRow.modelData.ip
                            color: root.copied === peerRow.modelData.ip ? theme.green
                                 : ipMa.containsMouse ? theme.text : theme.subtext0
                            font.pixelSize: theme.fontSizeMin
                            font.family: theme.font

                            MouseArea {
                                id: ipMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyText(peerRow.modelData.ip)
                            }
                        }
                    }
                }

                Text {
                    visible: root.sortedPeers.length > root.maxPeers
                    text: "+" + (root.sortedPeers.length - root.maxPeers) + " more"
                    color: theme.subtext0
                    font.pixelSize: theme.fontSizeMin
                    font.family: theme.font
                }
            }
        }
    }

    // ── Info polling: net-panel info every 10s (immediate refresh after DNS changes) ──
    Process {
        id: infoProc
        command: [root.dnsBin, "info"]
        running: false
        property bool rerun: false

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

        onRunningChanged: {
            if (!running && rerun) {
                rerun = false
                running = true
            }
        }
    }

    Timer {
        interval: 10000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!infoProc.running) infoProc.running = true
    }

    // ── DNS presets (single source of truth: the net-panel binary) ──
    Process {
        id: presetsProc
        command: [root.dnsBin, "dns", "list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim())
                    root.dnsProviders = data.presets || []
                } catch (e) {
                    console.log("NetPanel: failed to parse dns list:", e)
                }
            }
        }
    }

    // ── DNS set / reset ──
    // net-panel reports failure in its JSON (exit code is 0 either way).
    Process {
        id: dnsSetProc
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.dnsBusy = false
                var out = this.text.trim()
                try {
                    var data = JSON.parse(out.split("\n").pop())
                    if (data.success) {
                        root.dnsFeedbackOk = true
                        root.dnsFeedback = "✓ " + data.provider + " applied"
                        root.refreshInfo()
                    } else {
                        root.dnsFeedbackOk = false
                        root.dnsFeedback = "✗ " + (data.error || "failed")
                    }
                } catch (e) {
                    root.dnsFeedbackOk = false
                    root.dnsFeedback = out ? "✗ " + out : "✗ failed"
                }
            }
        }
    }

    // ── Speed test ──
    Process {
        id: speedTestProc
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.speedRunning !== root.speedRun) return   // cancelled or superseded
                root.speedTestRunning = false
                var at = Qt.formatTime(new Date(), "hh:mm")
                var output = this.text.trim()
                if (!output) {
                    root.speedResult = { error: "No results", at: at }
                    return
                }
                try {
                    var data = JSON.parse(output)
                    if (data.error) {
                        root.speedResult = { error: String(data.error), at: at }
                    } else {
                        root.speedResult = {
                            down: data.download_mbps, up: data.upload_mbps,
                            ping: data.ping_ms, server: data.server_name || "", at: at
                        }
                    }
                } catch (e) {
                    // plain-text output (not JSON)
                    root.speedResult = { error: output, at: at }
                }
            }
        }
    }

    // ── Copy to clipboard ──
    Process { id: copyProc; running: false }

    Timer {
        id: copyTimer
        interval: 1500
        onTriggered: root.copied = ""
    }
}
