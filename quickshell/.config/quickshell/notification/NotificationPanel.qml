import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property bool active: false
    property bool clearing: false
    property var dataSource: null
    signal close()

    clip: true
    implicitWidth: 360
    implicitHeight: 480

    // Sync from shared dataSource when available
    onDataSourceChanged: {
        if (dataSource) {
            dataSource.activeNotifsChanged.connect(syncFromDataSource)
            dataSource.historyNotifsChanged.connect(syncFromDataSource)
            syncFromDataSource()
        }
    }

    function syncFromDataSource() {
        if (root.dataSource && !root.clearing) {
            root.mergeNotifs(dataSource.activeNotifs, dataSource.historyNotifs)
        }
    }

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

    property var persistentNotifs: []

    function mergeNotifs(active, history) {
        if (root.clearing) return;

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

    function dismissNotif(id) {
        console.log("dismissNotif:", id);
        root.persistentNotifs = root.persistentNotifs.filter(function(n) { return n.id !== id; });
        var cmd = 'mkdir -p ~/.cache/quickshell; makoctl dismiss -n ' + id + ' 2>/dev/null; makoctl history -j 2>/dev/null | jq "map(.id) | max // 0" > ~/.cache/quickshell/max-cleared-id';
        dismissSingleProc.command = ["/bin/bash", "-c", cmd];
        dismissSingleProc.running = true;
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
                        if (root.clearing) return;
                        root.clearing = true;
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
                    onDismiss: function() { root.dismissNotif(modelData.id) }
                    onAction: function(id, action) { root.invokeAction(id, action) }
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
        running: !root.dataSource

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.dataSource) return
                try {
                    var data = JSON.parse(this.text);
                    root.mergeNotifs(data.active, data.history);
                } catch (e) {
                    console.log("Failed to parse notifications:", e);
                }
            }
        }

        onRunningChanged: {
            if (!running && !root.dataSource)
                fetchTimer.restart()
        }
    }

    Process {
        id: clearAllProc
        command: ["/bin/bash", "-c", "makoctl dismiss -a; mkdir -p ~/.cache/quickshell; makoctl history -j | jq 'map(.id) | max // 0' > ~/.cache/quickshell/max-cleared-id"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.clearing = false;
            }
        }
    }

    Process {
        id: dismissSingleProc
        command: ["makoctl", "dismiss", "-n", ""]
    }

    function invokeAction(id, action) {
        actionProc.command = ["makoctl", "invoke", "-n", String(id), action];
        actionProc.running = true;
    }

    Process {
        id: actionProc
        command: ["makoctl", "invoke"]
    }

    Timer {
        id: fetchTimer
        interval: 1000
        running: root.active && !root.dataSource && !fetchProc.running && !root.clearing
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.dataSource) fetchProc.running = true
        }
    }
}
