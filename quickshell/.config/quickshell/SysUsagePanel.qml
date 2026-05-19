import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property Theme theme: Theme {}
    property bool active: false
    signal close()

    property var ram: ({ total: 0, used: 0, pct: 0 })
    property var swap: ({ total: 0, used: 0, pct: 0 })
    property var processes: []

    clip: true
    implicitWidth: 420
    implicitHeight: 500

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
                text: "System Usage"
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

        // ── RAM bar ──
        Text {
            text: "RAM  " + root.ram.used + " / " + root.ram.total + " MB  (" + root.ram.pct + "%)"
            color: theme.subtext1
            font.pixelSize: theme.fontSize - 1
            font.family: theme.font
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: 8

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: theme.surface0
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                radius: 4
                color: root.ram.pct > 80 ? theme.red : root.ram.pct > 50 ? theme.yellow : theme.green
                width: parent.width * Math.min(1, root.ram.pct / 100)
            }
        }

        // ── Swap bar ──
        Text {
            text: "Swap  " + root.swap.used + " / " + root.swap.total + " MB  (" + root.swap.pct + "%)"
            color: theme.subtext1
            font.pixelSize: theme.fontSize - 1
            font.family: theme.font
            visible: root.swap.total > 0
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: 8
            visible: root.swap.total > 0

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: theme.surface0
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                radius: 4
                color: root.swap.pct > 50 ? theme.red : root.swap.pct > 20 ? theme.yellow : theme.green
                width: parent.width * Math.min(1, root.swap.pct / 100)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.surface0
        }

        // ── process list header ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Process"
                color: theme.subtext1
                font.pixelSize: theme.fontSize - 1
                font.bold: true
                font.family: theme.font
                Layout.fillWidth: true
            }

            Text {
                text: "RAM"
                color: theme.subtext1
                font.pixelSize: theme.fontSize - 1
                font.bold: true
                font.family: theme.font
                width: 50
                horizontalAlignment: Text.AlignRight
            }

            Text {
                text: "Swap"
                color: theme.subtext1
                font.pixelSize: theme.fontSize - 1
                font.bold: true
                font.family: theme.font
                width: 50
                horizontalAlignment: Text.AlignRight
            }

            Text {
                text: "%"
                color: theme.subtext1
                font.pixelSize: theme.fontSize - 1
                font.bold: true
                font.family: theme.font
                width: 40
                horizontalAlignment: Text.AlignRight
            }
        }

        // ── process list ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: procList
                anchors.fill: parent
                spacing: 4
                clip: true
                model: root.processes

                delegate: RowLayout {
                    required property var modelData
                    width: procList.width
                    spacing: 8

                    Text {
                        text: modelData.name
                        color: theme.text
                        font.pixelSize: theme.fontSize - 1
                        font.family: theme.font
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: modelData.rssMb + "M"
                        color: theme.subtext0
                        font.pixelSize: theme.fontSize - 1
                        font.family: theme.font
                        width: 50
                        horizontalAlignment: Text.AlignRight
                    }

                    Text {
                        text: modelData.swapMb > 0 ? modelData.swapMb + "M" : "—"
                        color: modelData.swapMb > 0 ? theme.surface1 : theme.surface0
                        font.pixelSize: theme.fontSize - 1
                        font.family: theme.font
                        width: 50
                        horizontalAlignment: Text.AlignRight
                    }

                    Text {
                        text: modelData.ramPct + "%"
                        color: modelData.ramPct > 10 ? theme.red : modelData.ramPct > 5 ? theme.yellow : theme.subtext0
                        font.pixelSize: theme.fontSize - 1
                        font.family: theme.font
                        width: 40
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }

    Process {
        id: fetchProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/mem-apps.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.ram = data.ram || { total: 0, used: 0, pct: 0 };
                    root.swap = data.swap || { total: 0, used: 0, pct: 0 };
                    root.processes = data.processes || [];
                } catch (e) {
                    console.log("Failed to parse mem-apps:", e);
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: root.active && !fetchProc.running
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchProc.running = true
    }
}
