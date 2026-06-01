import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property string weatherText: "--"
    property string weatherIcon: ""
    signal togglePanel()

    function refresh() {
        weatherProc.running = true
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        spacing: 2

        Text {
            id: iconText
            text: root.weatherIcon
            color: theme.subtext0
            font.pixelSize: theme.fontSize + 5
            font.weight: Font.Medium
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            id: textText
            text: root.weatherText
            color: theme.subtext0
            font.pixelSize: theme.fontSize - 1
            font.weight: Font.Medium
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.togglePanel()
            }
        }
    }

    Process {
        id: weatherProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/weather.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim();
                if (output) {
                    const outputs = output.split(/\s+/);
                    root.weatherIcon = outputs[0];
                    root.weatherText = outputs[1]
                }
            }
        }
    }

    Timer {
        interval: 1800000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }
}
