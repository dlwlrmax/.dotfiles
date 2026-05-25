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

    property var devices: []

    clip: true
    implicitWidth: 340
    implicitHeight: 300

    Rectangle {
        anchors.fill: parent
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 16
        bottomRightRadius: 16
        color: theme.color
        border.color: theme.surface0
        border.width: 2

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
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Battery Devices"
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

        Text {
            Layout.fillWidth: true
            visible: root.devices.length === 0
            text: "No battery devices found"
            color: theme.subtext0
            font.pixelSize: theme.fontSize
            font.family: theme.font
        }

        ColumnLayout {
            id: deviceList
            Layout.fillWidth: true
            spacing: 10
            visible: root.devices.length > 0

            Repeater {
                model: root.devices

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 60
                    radius: 10
                    color: theme.surface0

                    property string icon: {
                        if (modelData.status === "Charging") return "󰂄"
                        var cap = modelData.capacity
                        var lvl = modelData.capacity_level
                        if (lvl === "Full") return ""
                        if (lvl === "Critical") return ""
                        if (typeof cap === "number") {
                            if (cap >= 95) return ""
                            if (cap >= 75) return ""
                            if (cap >= 50) return ""
                            if (cap >= 25) return ""
                            return ""
                        }
                        if (lvl === "Normal") return ""
                        if (lvl === "Low") return ""
                        return ""
                    }

                    property string levelText: {
                        var cap = modelData.capacity
                        var lvl = modelData.capacity_level
                        if (typeof cap === "number") return cap + "%"
                        if (lvl) return lvl
                        return "?"
                    }

                    property string barColor: {
                        if (modelData.status === "Charging") return theme.green
                        var cap = modelData.capacity
                        var lvl = modelData.capacity_level
                        if (lvl === "Full") return theme.green
                        if (lvl === "Critical") return theme.red
                        if (lvl === "Low") return theme.peach
                        if (typeof cap === "number") {
                            if (cap >= 50) return theme.green
                            if (cap >= 25) return theme.yellow
                            return theme.red
                        }
                        if (lvl === "Normal") return theme.green
                        return theme.subtext0
                    }

                    property real barWidth: {
                        var cap = modelData.capacity
                        var lvl = modelData.capacity_level
                        if (typeof cap === "number") return cap / 100
                        if (lvl === "Full") return 1.0
                        if (lvl === "Normal") return 0.66
                        if (lvl === "Low") return 0.33
                        if (lvl === "Critical") return 0.1
                        return 0.5
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Text {
                            text: icon
                            color: barColor
                            font.pixelSize: theme.fontSize + 10
                            font.family: theme.font
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: modelData.model || modelData.name || "Battery"
                                    color: theme.text
                                    font.pixelSize: theme.fontSize
                                    font.weight: Font.Medium
                                    font.family: theme.font
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: levelText
                                    color: barColor
                                    font.pixelSize: theme.fontSize
                                    font.weight: Font.Bold
                                    font.family: theme.font
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 6
                                radius: 3
                                color: Qt.darker(theme.surface0, 1.2)

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    radius: 3
                                    color: barColor
                                    width: parent.width * Math.min(1, barWidth)
                                }
                            }

                            Text {
                                text: {
                                    var parts = []
                                    if (modelData.manufacturer) parts.push(modelData.manufacturer)
                                    parts.push(modelData.status || "Unknown")
                                    return parts.join(" · ")
                                }
                                color: theme.subtext0
                                font.pixelSize: theme.fontSize - 2
                                font.family: theme.font
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: fetchProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/battery-all.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text)
                    root.devices = data.devices || []
                } catch (e) {
                    console.log("Failed to parse battery devices:", e)
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: root.active && !fetchProc.running
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchProc.running = true
    }
}
