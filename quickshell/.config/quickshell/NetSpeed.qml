import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Text {
    id: root
    property Theme theme: Theme {}
    property string netText: "󰤫 --"

    text: netText
    color: theme.subtext0
    font.pixelSize: theme.fontSize - 1
    font.weight: Font.Medium

    Process {
        id: netProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/netspeed.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim();
                if (output) {
                    root.netText = output;
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
