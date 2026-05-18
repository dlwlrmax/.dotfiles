import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property Theme theme: Theme {}
    property bool active: false
    signal close()

    clip: true
    implicitWidth: 360
    implicitHeight: 480

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: -16
        radius: 16
        color: theme.color
        border.color: theme.surface0
        border.width: 2
    }

    property var persistentNotifs: []

    function mergeNotifs(active, history) {
        var seenIds = {};
        var merged = [];
        var changed = false;

        for (var i = 0; i < root.persistentNotifs.length; i++) {
            var pn = root.persistentNotifs[i];
            seenIds[pn.id] = true;
            merged.push(pn);
        }

        for (var j = 0; j < active.length; j++) {
            var an = active[j];
            if (!seenIds[an.id]) {
                seenIds[an.id] = true;
                merged.push(an);
                changed = true;
            }
        }

        for (var k = 0; k < history.length; k++) {
            var hn = history[k];
            if (!seenIds[hn.id]) {
                seenIds[hn.id] = true;
                merged.push(hn);
                changed = true;
            }
        }

        if (changed || merged.length !== root.persistentNotifs.length) {
            root.persistentNotifs = merged;
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
                text: "Notifications" + (notifList.count > 0 ? " (" + notifList.count + ")" : "")
                color: theme.text
                font.pixelSize: theme.fontSize + 1
                font.bold: true
                font.family: theme.font
                Layout.fillWidth: true
            }

            Text {
                text: "Clear All"
                color: theme.blue
                font.pixelSize: theme.fontSize - 1
                font.family: theme.font

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.persistentNotifs = [];
                        clearAllProc.running = true;
                    }
                }
            }

            Text {
                text: "×"
                color: theme.subtext0
                font.pixelSize: theme.fontSize + 4

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

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: notifList
                anchors.fill: parent
                spacing: 8
                clip: true
                model: root.persistentNotifs

                delegate: NotificationCard {
                    theme: root.theme
                    notifData: modelData
                    width: notifList.width
                }
            }

            Text {
                anchors.centerIn: parent
                visible: notifList.count === 0
                text: "No notifications"
                color: theme.subtext0
                font.pixelSize: theme.fontSize
                font.family: theme.font
            }
        }
    }

    Process {
        id: fetchProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/mako-notifs.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.mergeNotifs(data.active, data.history);
                } catch (e) {
                    console.log("Failed to parse notifications:", e);
                }
            }
        }
    }

    Process {
        id: clearAllProc
        command: ["/bin/bash", "-c", "makoctl dismiss -a; mkdir -p ~/.cache/quickshell; makoctl history -j | jq 'map(.id) | max // 0' > ~/.cache/quickshell/max-cleared-id"]
    }

    Timer {
        interval: 1000
        running: root.active && !fetchProc.running
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchProc.running = true
    }
}
