import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.common

// Quick toggles: output/mic mute, do not disturb, idle inhibit, power profile,
// bluetooth. State is read when `active` becomes true and after each action.
Item {
    id: root
    property Theme theme: ThemeStore
    property bool active: false
    property var volumeData: null   // DataProviders.volumeData
    property var notifData: null    // DataProviders.notifData

    readonly property bool outMuted: volumeData ? volumeData.muted : false
    readonly property bool dnd: notifData ? notifData.dnd : false
    readonly property var micNode: volumeData ? volumeData.source : null
    readonly property bool micMuted: volumeData ? volumeData.micMuted : false

    property string profile: ""          // power-saver | balanced | performance
    property bool btAvailable: false
    property bool btPowered: false

    readonly property var profiles: ["power-saver", "balanced", "performance"]

    function profileLabel(p) {
        return p === "power-saver" ? "Power saver" : p === "performance" ? "Performance" : p === "balanced" ? "Balanced" : "--"
    }

    function refresh() {
        if (!profileProc.running) profileProc.running = true
        if (!btProc.running) btProc.running = true
    }

    function cycleProfile() {
        var i = profiles.indexOf(profile)
        var next = profiles[(i + 1) % profiles.length]
        profileSetProc.command = ["timeout", "5", "powerprofilesctl", "set", next]
        profile = next   // optimistic; re-read below
        profileSetProc.running = true
    }

    function toggleBluetooth() {
        btSetProc.command = ["timeout", "5", "bluetoothctl", "power", btPowered ? "off" : "on"]
        btPowered = !btPowered
        btSetProc.running = true
    }

    implicitHeight: grid.implicitHeight
    Layout.fillWidth: true

    onActiveChanged: if (active) refresh()

    GridLayout {
        id: grid
        anchors.left: parent.left
        anchors.right: parent.right
        columns: 3
        rowSpacing: 8
        columnSpacing: 8

        Tile {
            theme: root.theme
            icon: root.outMuted ? "󰝟" : "󰕾"
            label: "Sound"
            state: root.outMuted ? "Muted" : (root.volumeData ? root.volumeData.volumeLevel + "%" : "On")
            active: !root.outMuted
            clr: theme.green
            onClicked: if (root.volumeData) root.volumeData.toggleMute()
        }

        Tile {
            theme: root.theme
            icon: root.micMuted ? "󰍭" : "󰍬"
            label: "Microphone"
            state: !root.micNode ? "No input" : root.micMuted ? "Muted" : "On"
            active: !!root.micNode && !root.micMuted
            clr: theme.blue
            onClicked: if (root.volumeData) root.volumeData.toggleMic()
        }

        Tile {
            theme: root.theme
            icon: root.dnd ? "󰂛" : "󰂚"
            label: "Do not disturb"
            state: root.dnd ? "On" : "Off"
            active: root.dnd
            clr: theme.mauve
            onClicked: if (root.notifData) root.notifData.toggleDnd()
        }

        Tile {
            theme: root.theme
            icon: ShellState.idleInhibit ? "󰈈" : "󰈉"
            label: "Stay awake"
            state: ShellState.idleInhibit ? "Screen won't lock" : "Normal"
            active: ShellState.idleInhibit
            clr: theme.yellow
            onClicked: ShellState.idleInhibit = !ShellState.idleInhibit
        }

        Tile {
            // Fills the last row when there is no Bluetooth tile beside it.
            Layout.columnSpan: root.btAvailable ? 1 : 2
            theme: root.theme
            icon: root.profile === "performance" ? "" : root.profile === "power-saver" ? "" : ""
            label: "Power profile"
            state: root.profileLabel(root.profile)
            active: root.profile === "performance"
            clr: theme.peach
            onClicked: root.cycleProfile()
        }

        Tile {
            theme: root.theme
            visible: root.btAvailable
            icon: ""
            label: "Bluetooth"
            state: root.btPowered ? "On" : "Off"
            active: root.btPowered
            clr: theme.sapphire
            onClicked: root.toggleBluetooth()
        }
    }

    Process {
        id: profileProc
        command: ["timeout", "3", "powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.profile = this.text.trim()
        }
    }

    Process {
        id: profileSetProc
        running: false
        onRunningChanged: if (!running) profileProc.running = true
    }

    Process {
        id: btProc
        // bluetoothctl waits forever for bluez when the service is down, so bound it.
        command: ["timeout", "3", "bluetoothctl", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = this.text
                root.btAvailable = t.indexOf("Controller") >= 0
                root.btPowered = /Powered:\s*yes/.test(t)
            }
        }
    }

    Process {
        id: btSetProc
        running: false
        onRunningChanged: if (!running) btProc.running = true
    }
}
