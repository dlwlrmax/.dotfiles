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
                            property real _dragVal: 0
                            Layout.fillWidth: true
                            implicitHeight: 6

                            function modelVol() {
                                return modelData ? (modelData.volume / 100) : 0;
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

                                function clampVol(x) { return Math.max(0, Math.min(1.5, x)); }

                                onPressed: dragging = true
                                onReleased: dragging = false

                                onPositionChanged: mouse => {
                                    if (dragging) {
                                        sinkSlider._dragVal = clampVol(mouse.x / parent.width);
                                    }
                                }
                                onClicked: mouse => {
                                    var v = clampVol(mouse.x / parent.width);
                                    sinkSlider._dragVal = v;
                                    var vol = Math.round(v * 100);
                                    root.pendingCmd = ["pactl", "set-sink-volume", modelData.name, vol + "%"];
                                    root.pendingRefresh = true;
                                    pactlProc.running = true;
                                }
                            }
                        }

                        Text {
                            text: modelData ? modelData.volume + "%" : "0%"
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
                            appId: modelData.icon || modelData.application || ""
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
                                color: modelData && modelData.muted ? theme.surface1 : theme.green
                                width: parent.width * Math.min(1, streamSliderDelegate._val)
                            }

                            MouseArea {
                                id: streamDragArea
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                property bool dragging: false

                                onPressed: dragging = true
                                onReleased: dragging = false

                                onPositionChanged: mouse => {
                                    if (dragging) {
                                        streamSliderDelegate._val = Math.max(0, Math.min(1.5, mouse.x / parent.width));
                                    }
                                }
                                onClicked: mouse => {
                                    streamSliderDelegate._val = Math.max(0, Math.min(1.5, mouse.x / parent.width));
                                    var vol = Math.round(streamSliderDelegate._val * 100);
                                    root.pendingCmd = ["pactl", "set-sink-input-volume", String(modelData.id), vol + "%"];
                                    root.pendingRefresh = true;
                                    pactlProc.running = true;
                                }
                            }
                        }

                        Text {
                            text: modelData ? modelData.volume + "%" : "0%"
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
                root.pendingRefresh = false;
                fetchProc.running = true;
            }
        }
    }

    Process {
        id: fetchProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/volume-streams.sh"]

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

    Timer {
        interval: 1000
        running: root.active && !fetchProc.running
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchProc.running = true
    }
}
