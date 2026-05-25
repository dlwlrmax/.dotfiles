import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property bool active: false
    signal close()

    property string pendingAction: ""
    property bool confirming: false

    property string holdAction: ""
    property real holdProgress: 0
    property string holdKey: ""

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
        if (active) root.forceActiveFocus()
    }

    Keys.onPressed: {
        if (event.isAutoRepeat || holdAction) return
        var key = event.text.toUpperCase()
        var map = { "L": "lock", "R": "reboot", "S": "shutdown", "O": "logout" }
        var act = map[key]
        if (!act) return
        if (act === "lock") {
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
    implicitWidth: 260
    implicitHeight: 320

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: theme.color
        border.color: theme.surface0
        border.width: 2
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: confirming ? "Confirm" : (holdAction ? "Hold " + holdKey + "..." : "Power Menu")
                color: confirming ? theme.red : (holdAction ? theme.peach : theme.text)
                font.pixelSize: theme.fontSize + 1
                font.bold: true
                font.family: theme.font
                Layout.fillWidth: true
            }

            Text {
                text: holdAction ? Math.round(holdProgress * 100) + "%" : "×"
                color: holdAction ? theme.subtext0 : theme.subtext0
                font.pixelSize: theme.fontSize + (holdAction ? 0 : 4)

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
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
                }
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
                    var labels = { reboot: "reboot", shutdown: "shut down", logout: "log out" }
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
                    radius: 8
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
                    radius: 8
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
                    { icon: "\uF023", label: "Lock",     key: "L", action: "lock",     color: theme.lavender },
                    { icon: "\uF021", label: "Reboot",   key: "R", action: "reboot",   color: theme.peach },
                    { icon: "\uF011", label: "Shutdown", key: "S", action: "shutdown", color: theme.red },
                    { icon: "\uF08B", label: "Logout",   key: "O", action: "logout",   color: theme.mauve }
                ]

                delegate: Rectangle {
                    id: btn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    radius: 12
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
                            text: "[" + modelData.key + "] " + modelData.label
                            color: isHolding ? modelData.color : theme.text
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                            font.weight: isHolding ? Font.Bold : Font.Medium
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.action === "reboot" ||
                                modelData.action === "shutdown" ||
                                modelData.action === "logout") {
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
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/power-actions.sh", pendingAction]
        onRunningChanged: {
            if (!running && pendingAction) {
                pendingAction = ""
                confirming = false
            }
        }
    }
}
