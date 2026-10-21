import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: ThemeStore
    property bool active: false
    signal close()

    property string pendingAction: ""
    property bool confirming: false

    property string holdAction: ""
    property real holdProgress: 0
    property string holdKey: ""
    property bool canHibernate: false

    focus: true
    activeFocusOnTab: true

    Keys.onEscapePressed: {
        if (confirming) {
            confirming = false
            pendingAction = ""
        } else if (holdAction) {
            holdAction = ""
            holdKey = ""
            holdProgress = 0
        } else {
            root.close()
        }
    }

    onActiveChanged: {
        if (active) {
            root.forceActiveFocus()
            if (!hibernateCheck.running) hibernateCheck.running = true
        }
    }

    // Hibernate needs swap + a resume setup; only offer it when logind says it works.
    Process {
        id: hibernateCheck
        command: ["bash", "-c", "busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate | grep -q '\"yes\"' && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: root.canHibernate = this.text.trim() === "yes"
        }
    }

    Keys.onPressed: {
        if (event.isAutoRepeat || holdAction) return
        var key = event.text.toUpperCase()
        var map = { "L": "lock", "Z": "suspend", "H": "hibernate", "R": "reboot", "S": "shutdown", "O": "logout" }
        var act = map[key]
        if (!act || (act === "hibernate" && !canHibernate)) return
        if (act === "lock" || act === "suspend") {
            pendingAction = act
            actionProc.running = true
        } else {
            holdAction = act
            holdKey = key
            holdProgress = 0
        }
    }

    Keys.onReleased: {
        if (event.isAutoRepeat) return
        if (event.text.toUpperCase() === holdKey) {
            if (holdProgress < 1.0) {
                holdAction = ""
                holdKey = ""
                holdProgress = 0
            }
        }
    }

    Timer {
        id: holdTimer
        interval: 30
        repeat: true
        running: holdAction !== ""
        onTriggered: {
            holdProgress += 0.02
            if (holdProgress >= 1.0) {
                holdProgress = 1.0
                stop()
                pendingAction = holdAction
                holdAction = ""
                holdKey = ""
                holdProgress = 0
                actionProc.running = true
            }
        }
    }

    clip: true
    implicitWidth: 300
    implicitHeight: 410

    // Centered overlay (not attached to the bar): rounded on all sides.
    Rectangle {
        anchors.fill: parent
        radius: theme.panelRadius
        color: theme.panelColorSolid
        border.color: theme.surface1
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        PanelHeader {
            theme: root.theme
            title: confirming ? "Confirm" : (holdAction ? "Hold " + holdKey + "\u2026 " + Math.round(holdProgress * 100) + "%" : "Power")
            onClose: {
                if (confirming) { confirming = false; pendingAction = "" }
                else if (holdAction) { holdAction = ""; holdKey = ""; holdProgress = 0 }
                else root.close()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.surface0
        }

        ColumnLayout {
            id: confirmView
            Layout.fillWidth: true
            spacing: 12
            visible: confirming

            Text {
                Layout.fillWidth: true
                text: {
                    var labels = { reboot: "reboot", shutdown: "shut down", logout: "log out", hibernate: "hibernate" }
                    return "Are you sure you want\nto " + (labels[pendingAction] || pendingAction) + "?"
                }
                color: theme.subtext1
                font.pixelSize: theme.fontSize
                font.family: theme.font
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: theme.radiusLg
                    color: theme.surface0

                    Text {
                        anchors.centerIn: parent
                        text: "No"
                        color: theme.subtext0
                        font.pixelSize: theme.fontSize
                        font.family: theme.font
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            confirming = false
                            pendingAction = ""
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: theme.radiusLg
                    color: theme.red

                    Text {
                        anchors.centerIn: parent
                        text: "Yes"
                        color: theme.base
                        font.pixelSize: theme.fontSize
                        font.family: theme.font
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            actionProc.running = true
                        }
                    }
                }
            }
        }

        GridLayout {
            id: actionGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rowSpacing: 10
            columnSpacing: 10
            visible: !confirming

            Repeater {
                model: [
                    { icon: "\uF023", label: "Lock",      key: "L", action: "lock",      sub: "Lock the screen",          color: theme.lavender },
                    { icon: "\uF186", label: "Sleep",     key: "Z", action: "suspend",   sub: "Suspend to RAM",           color: theme.sapphire },
                    { icon: "\uF2DC", label: "Hibernate", key: "H", action: "hibernate", sub: "Save to disk and power off", color: theme.blue },
                    { icon: "\uF08B", label: "Log out",   key: "O", action: "logout",    sub: "End this session",         color: theme.mauve },
                    { icon: "\uF021", label: "Reboot",    key: "R", action: "reboot",    sub: "Restart the computer",     color: theme.peach },
                    { icon: "\uF011", label: "Shut down", key: "S", action: "shutdown",  sub: "Power off",                color: theme.red }
                ].filter(function (t) { return t.action !== "hibernate" || root.canHibernate })

                delegate: Rectangle {
                    id: btn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 74
                    radius: theme.radiusXl
                    color: theme.surface0

                    property bool isHolding: root.holdKey === modelData.key

                    Rectangle {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        width: isHolding ? parent.width * root.holdProgress : 0
                        height: parent.height
                        radius: parent.radius
                        color: modelData.color
                        opacity: 0.25
                        clip: true
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.icon
                            font.pixelSize: isHolding ? 26 : 22
                            font.family: theme.font
                            color: modelData.color
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.label + "  " + modelData.key
                            color: isHolding ? modelData.color : theme.text
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.fontUi
                            font.weight: isHolding ? Font.Bold : Font.Medium
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.sub
                            color: theme.overlay0
                            font.pixelSize: theme.fontSizeMin - 1
                            font.family: theme.fontUi
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.action !== "lock" && modelData.action !== "suspend") {
                                pendingAction = modelData.action
                                confirming = true
                            } else {
                                pendingAction = modelData.action
                                actionProc.running = true
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: actionProc
        command: ["bash", theme.scriptDir + "/power-actions.sh", pendingAction]
        onRunningChanged: {
            if (!running && pendingAction) {
                pendingAction = ""
                confirming = false
            }
        }
    }
}
