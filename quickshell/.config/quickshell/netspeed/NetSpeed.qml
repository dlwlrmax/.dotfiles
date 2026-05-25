import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Column {
    id: root
    property Theme theme: Theme {}
    property string dlText: "--"
    property string ulText: "--"
    spacing: 0
    width: 45

    Layout.alignment: Qt.AlignVCenter

    RowLayout {
        spacing: 2
        width: parent.width

        Text {
            text: ""
            color: root.theme.subtext0
            font.pixelSize: root.theme.fontSize
            font.weight: Font.Medium
        }

        Text {
            text: root.dlText
            color: root.theme.subtext0
            font.pixelSize: root.theme.fontSize - 2
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    RowLayout {
        spacing: 2
        width: parent.width

        Text {
            text: ""
            color: root.theme.subtext0
            font.pixelSize: root.theme.fontSize
            font.weight: Font.Medium
        }

        Text {
            text: root.ulText
            color: root.theme.subtext0
            font.pixelSize: root.theme.fontSize - 2
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    Process {
        id: netProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/netspeed.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim();
                if (!output) {
                    root.dlText = "--"
                    root.ulText = "--"
                } else {
                    var parts = output.split("|")
                    if (parts.length >= 2) {
                        root.dlText = parts[0] || "--"
                        root.ulText = parts[1] || "--"
                    }
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: netProc.running = true
    }
}
