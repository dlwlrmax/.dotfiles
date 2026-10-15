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

    clip: true
    implicitWidth: 380
    implicitHeight: 520

    property var sinks: []
    property var streams: []

    property var pendingCmd: []
    property bool pendingRefresh: false

    property bool eeActive: false
    property string eePreset: ""
    property int eeToggleGen: 0
    property int eePendingToggles: 0
    property bool needsStatus: false

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
            id: header
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Volume Control"
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
            text: "Output Device"
            color: theme.subtext1
            font.pixelSize: theme.fontSize - 1
            font.weight: Font.Medium
            font.family: theme.font
        }

        ColumnLayout {
            id: sinkList
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.sinks

                delegate: ColumnLayout {
                    required property var modelData
                    spacing: 6
                    Layout.fillWidth: true

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: modelData.default ? "◉" : "○"
                            color: modelData.default ? theme.mauve : theme.surface0
                            font.pixelSize: theme.fontSize + 2

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.pendingCmd = ["pactl", "set-default-sink", modelData.name];
                                    root.pendingRefresh = true;
                                    pactlProc.running = true;
                                }
                            }
                        }

                        Text {
                            text: modelData.description || modelData.name
                            color: theme.text
                            font.pixelSize: theme.fontSize
                            font.weight: Font.Medium
                            font.family: theme.font
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: modelData.muted ? "" : ""
                            color: modelData.muted ? theme.surface1 : theme.subtext0
                            font.pixelSize: theme.fontSize

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.pendingCmd = ["pactl", "set-sink-mute", modelData.name, "toggle"];
                                    root.pendingRefresh = true;
                                    pactlProc.running = true;
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item {
                            id: sinkSlider
                            property real _dragVal: modelData ? modelData.volume / 100 : 0
                            Layout.fillWidth: true
                            implicitHeight: 6

                            Binding on _dragVal {
                                when: !sinkDragArea.dragging
                                value: modelData ? modelData.volume / 100 : 0
                            }

                            function modelVol() {
                                return modelData ? (modelData.volume / 100) : 0;
                            }

                            function clampVol(x) { return Math.max(0, Math.min(1, x)); }

                            function commitVol() {
                                var v = sinkSlider._dragVal;
                                var vol = Math.round(v * 100);
                                root.pendingCmd = ["pactl", "set-sink-volume", modelData.name, vol + "%"];
                                root.pendingRefresh = true;
                                pactlProc.running = true;
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 3
                                color: theme.surface0
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                radius: 3
                                color: modelData && modelData.muted ? theme.surface1 : theme.mauve
                                width: {
                                    var rv = sinkDragArea.dragging ? sinkSlider._dragVal : sinkSlider.modelVol();
                                    return parent.width * Math.min(1, rv);
                                }
                            }

                            MouseArea {
                                id: sinkDragArea
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                property bool dragging: false

                                onPressed: mouse => {
                                    sinkSlider._dragVal = clampVol(mouse.x / parent.width)
                                    dragging = true
                                }

                                onPositionChanged: mouse => {
                                    if (dragging) {
                                        sinkSlider._dragVal = clampVol(mouse.x / parent.width)
                                        sinkDragTimer.restart()
                                    }
                                }

                                onReleased: {
                                    sinkDragTimer.stop()
                                    if (dragging) sinkSlider.commitVol()
                                    dragging = false
                                }

                                onClicked: mouse => {
                                    sinkSlider._dragVal = clampVol(mouse.x / parent.width)
                                    sinkSlider.commitVol()
                                }
                            }

                            Timer {
                                id: sinkDragTimer
                                interval: 80
                                repeat: false
                                onTriggered: sinkSlider.commitVol()
                            }
                        }

                        Text {
                            text: (sinkDragArea.dragging ? Math.round(sinkSlider._dragVal * 100) : (modelData ? modelData.volume : 0)) + "%"
                            color: modelData && modelData.muted ? theme.surface1 : theme.subtext0
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                            width: 40
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.sinks.length === 0
                text: "No output devices"
                color: theme.subtext0
                font.pixelSize: theme.fontSize - 1
                font.family: theme.font
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.surface0
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: eeRow.implicitHeight

            // Declared before the row so the repair button's MouseArea sits on top
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // Flip immediately so the switch animates; queue the toggle so rapid clicks aren't dropped.
                    // Bumping eeToggleGen invalidates any status read already in flight.
                    root.eeActive = !root.eeActive;
                    root.eeToggleGen++;
                    root.eePendingToggles++;
                    if (!eeToggleProc.running) eeToggleProc.running = true;
                }
            }

            RowLayout {
                id: eeRow
                anchors.fill: parent
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: root.eePreset || "EasyEffects"
                        color: theme.text
                        font.pixelSize: theme.fontSize
                        font.weight: Font.Medium
                        font.family: theme.font
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Always shown so the row height doesn't jump when the preset name arrives
                    Text {
                        text: root.eePreset ? "EasyEffects" : "No preset loaded"
                        color: theme.subtext0
                        font.pixelSize: theme.fontSize - 2
                        font.family: theme.font
                    }
                }

                // Repair silent playback (stalled EE chain / sink resume glitch)
                Text {
                    text: repairProc.running ? "…" : "↻"
                    color: repairProc.running ? theme.surface1 : theme.subtext0
                    font.pixelSize: theme.fontSize + 1
                    font.family: theme.font

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!repairProc.running) repairProc.running = true;
                        }
                    }
                }

                // Visual-only switch; the row's MouseArea handles the toggle
                Rectangle {
                    implicitWidth: 34
                    implicitHeight: 18
                    radius: height / 2
                    color: root.eeActive ? theme.green : theme.surface0
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width: parent.height - 4
                        height: width
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.eeActive ? parent.width - width - 2 : 2
                        color: root.eeActive ? theme.base : theme.subtext0
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }

        Text {
            text: "Applications" + (streamList.count > 0 ? " (" + streamList.count + ")" : "")
            color: theme.subtext1
            font.pixelSize: theme.fontSize - 1
            font.weight: Font.Medium
            font.family: theme.font
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: streamList
                anchors.fill: parent
                spacing: 8
                clip: true
                model: root.streams

                delegate: ColumnLayout {
                    required property var modelData
                    spacing: 6
                    width: streamList.width

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        AppIcon {
                            appId: modelData.application || ""
                            iconName: modelData.icon || ""
                            fallbackIcon: "audio-x-generic"
                            size: 22
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: modelData.name || modelData.application || "Unknown"
                            color: theme.text
                            font.pixelSize: theme.fontSize
                            font.family: theme.font
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: modelData.muted ? "" : ""
                            color: modelData.muted ? theme.surface1 : theme.subtext0
                            font.pixelSize: theme.fontSize

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.pendingCmd = ["pactl", "set-sink-input-mute", String(modelData.id), "toggle"];
                                    root.pendingRefresh = true;
                                    pactlProc.running = true;
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item {
                            id: streamSliderDelegate
                            property real _val: modelData ? modelData.volume / 100 : 0
                            Layout.fillWidth: true
                            implicitHeight: 6

                            Binding on _val {
                                when: !streamDragArea.dragging
                                value: modelData ? modelData.volume / 100 : 0
                            }

                            function clampVol(x) { return Math.max(0, Math.min(1, x)); }

                            function commitVol() {
                                var v = streamSliderDelegate._val;
                                var vol = Math.round(v * 100);
                                root.pendingCmd = ["pactl", "set-sink-input-volume", String(modelData.id), vol + "%"];
                                root.pendingRefresh = true;
                                pactlProc.running = true;
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 3
                                color: theme.surface0
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                radius: 3
                                color: modelData && modelData.muted ? theme.surface1 : theme.volumeNormalColor
                                width: parent.width * Math.min(1, streamSliderDelegate._val)
                            }

                            MouseArea {
                                id: streamDragArea
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                property bool dragging: false

                                onPressed: mouse => {
                                    streamSliderDelegate._val = clampVol(mouse.x / parent.width)
                                    dragging = true
                                }

                                onPositionChanged: mouse => {
                                    if (dragging) {
                                        streamSliderDelegate._val = clampVol(mouse.x / parent.width)
                                        streamDragTimer.restart()
                                    }
                                }

                                onReleased: {
                                    streamDragTimer.stop()
                                    if (dragging) streamSliderDelegate.commitVol()
                                    dragging = false
                                }

                                onClicked: mouse => {
                                    streamSliderDelegate._val = clampVol(mouse.x / parent.width)
                                    streamSliderDelegate.commitVol()
                                }
                            }

                            Timer {
                                id: streamDragTimer
                                interval: 80
                                repeat: false
                                onTriggered: streamSliderDelegate.commitVol()
                            }
                        }

                        Text {
                            text: (streamDragArea.dragging ? Math.round(streamSliderDelegate._val * 100) : (modelData ? modelData.volume : 0)) + "%"
                            color: modelData && modelData.muted ? theme.surface1 : theme.subtext0
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                            width: 40
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: streamList.count === 0
                    text: "No active streams"
                    color: theme.subtext0
                    font.pixelSize: theme.fontSize
                    font.family: theme.font
                }
            }
        }
    }

    Process {
        id: pactlProc
        command: root.pendingCmd
        onRunningChanged: {
            if (!running && root.pendingRefresh) {
                root.pendingRefresh = false
                if (!fetchProc.running) fetchProc.running = true
            }
        }
    }

    Process {
        id: fetchProc
        command: ["bash", theme.scriptDir + "/volume-streams.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.sinks = data.sinks || [];
                    root.streams = data.streams || [];
                } catch (e) {
                    console.log("Failed to parse volume streams:", e);
                }
            }
        }
    }

    // Returns the last stdout line matching re, ignoring stray log lines; null if none match.
    function lastMatch(text, re) {
        var lines = text.split("\n");
        for (var i = lines.length - 1; i >= 0; i--) {
            var l = lines[i].trim();
            if (re.test(l)) return l;
        }
        return null;
    }

    function requestStatus() {
        if (eeStatusProc.running) root.needsStatus = true;
        else eeStatusProc.running = true;
    }

    function requestPreset() {
        if (!eePresetProc.running) eePresetProc.running = true;
    }

    onActiveChanged: if (active) requestPreset()

    Process {
        id: eeStatusProc
        // easyeffects -b 3 emits the global bypass status: 1 = bypassed (effects off), 2 = active (effects on)
        command: ["easyeffects", "-b", "3"]
        property int startGen: 0
        stdout: StdioCollector {
            onStreamFinished: {
                // Drop reads that started before a click or overlap a pending toggle; they report the old state.
                if (eeStatusProc.startGen !== root.eeToggleGen || root.eePendingToggles > 0) return;
                var s = root.lastMatch(this.text, /^[12]$/);
                if (s !== null) root.eeActive = s === "2";
            }
        }
        onRunningChanged: {
            if (running) {
                startGen = root.eeToggleGen
            } else if (root.needsStatus && root.active) {
                // A status read was requested while this poll was in flight; run it now.
                root.needsStatus = false
                eeStatusProc.running = true
            }
        }
    }

    Process {
        id: eePresetProc
        // Name of the last loaded output preset (empty if none). Changes rarely, so not polled.
        command: ["easyeffects", "-a", "output"]
        stdout: StdioCollector {
            onStreamFinished: root.eePreset = root.lastMatch(this.text, /./) || ""
        }
    }

    Process {
        id: repairProc
        command: ["bash", theme.scriptDir + "/audio-repair.sh"]
        onRunningChanged: {
            if (!running) {
                if (!fetchProc.running) fetchProc.running = true
                root.requestStatus()
                root.requestPreset()
            }
        }
    }

    Process {
        id: eeToggleProc
        command: ["easyeffects", "--bypass-toggle"]
        onRunningChanged: {
            if (running) return
            // Also invalidate polls that started while this toggle was still applying.
            root.eeToggleGen++
            root.eePendingToggles = Math.max(0, root.eePendingToggles - 1)
            if (root.eePendingToggles > 0) {
                // More clicks queued while this toggle ran.
                eeToggleProc.running = true
            } else {
                root.requestStatus()
                root.requestPreset()
            }
        }
    }

    Timer {
        interval: 1500
        running: root.active && !fetchProc.running
        repeat: true
        triggeredOnStart: true

        // Poll EE status less often than streams (every ~3rd tick).
        property int eeTick: 0

        onTriggered: {
            if (root.active && !fetchProc.running) fetchProc.running = true;

            eeTick = (eeTick + 1) % 3
            if (eeTick === 0 && root.active && !eeStatusProc.running) eeStatusProc.running = true;
        }
    }
}
