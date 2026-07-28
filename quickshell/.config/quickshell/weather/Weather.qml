import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property var dataSource: null
    property string _rawText: dataSource ? dataSource.weatherText : ""
    property string weatherText: _rawText && _rawText !== "--" ? _rawText : ""
    property string weatherIcon: {
        var ico = dataSource ? dataSource.weatherIcon : ""
        return ico || "\uF0C2"  //  cloud fallback
    }
    signal togglePanel()

    function refresh() {
        if (dataSource) {
            dataSource.refresh()
        } else {
            weatherProc.running = true
        }
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
            font.pixelSize: theme.fontSize
            font.weight: Font.Medium
            font.family: theme.font
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
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/weather.sh"]
        running: !root.dataSource

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.dataSource) return
                var output = this.text.trim();
                if (!output) return;
                const outputs = output.split(/\s+/);
                if (outputs.length >= 2 && outputs[1] !== "--") {
                    root.weatherIcon = outputs[0];
                    root.weatherText = outputs[1]
                } else if (outputs.length >= 1 && outputs[0]) {
                    // Show fallback icon on load failure
                    root.weatherIcon = "\uF0C2"
                    root.weatherText = ""
                }
            }
        }
    }

    Timer {
        interval: 1800000
        running: !root.dataSource
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }
}
