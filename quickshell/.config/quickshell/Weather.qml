import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Text {
    id: root
    property Theme theme: Theme {}
    property string weatherText: "󰅛 --"

    text: weatherText
    color: theme.subtext0
    font.pixelSize: theme.fontSize - 1
    font.weight: Font.Medium

    Process {
        id: weatherProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/weather.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim();
                if (output) {
                    root.weatherText = output;
                }
            }
        }
    }

    Timer {
        interval: 1800000  // 30 minutes
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }
}
