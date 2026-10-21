import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.common

Item {
    id: root
    property Theme theme: ThemeStore
    property bool active: false
    signal close()

    clip: true
    implicitWidth: theme.panelWidthM
    implicitHeight: 640

    // Live from Pipewire while the panel is open. Physical devices only: ALSA or a
    // hardware bus (pci/usb/bluetooth); skips virtual ones (EasyEffects, null sinks).
    function isPhysical(n) {
        var p = n.properties || {}
        return p["device.api"] === "alsa" || !!p["device.bus"]
    }
    readonly property var audioNodes: active ? Pipewire.nodes.values.filter(n => n.audio) : []
    readonly property var sinks: audioNodes.filter(n => n.isSink && !n.isStream && isPhysical(n))
    readonly property var sources: audioNodes.filter(n => !n.isSink && !n.isStream && isPhysical(n))
    // Playback streams; paused (corked) ones are hidden like before.
    readonly property var streams: audioNodes.filter(n => n.isSink && n.isStream
        && (n.properties || {})["pulse.corked"] !== "true")

    // Volume/mute/properties are only populated for tracked nodes.
    PwObjectTracker { objects: root.audioNodes }

    property bool eeActive: false
    property string eePreset: ""
    property int eeToggleGen: 0
    property int eePendingToggles: 0
    property var eePresets: []          // output preset names from `easyeffects -p`
    property bool presetMenuOpen: false
    property var pendingPresetCmd: []
    property bool needsStatus: false

    PanelBackground {
        anchors.fill: parent
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        PanelHeader {
            theme: root.theme
            title: "Volume Control"
            onClose: root.close()
        }

        SectionCard {
            theme: root.theme
            title: "Output Device"

    ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: root.sinks
                    delegate: DeviceRow {
                        required property var modelData
                        theme: root.theme
                        node: modelData
                        isDefault: Pipewire.defaultAudioSink === modelData
                        onMakeDefault: Pipewire.preferredDefaultAudioSink = modelData
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
        }

        SectionCard {
            theme: root.theme
            title: "Effects"

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

                        // Click the name to pick a preset; the rest of the row toggles bypass.
                        // fillWidth children let the column actually take the row's spare width;
                        // without them a ColumnLayout caps itself at its preferred width.
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: presetNameText.implicitHeight

                            // Plain anchoring, not a layout: the name takes its natural width and
                            // only elides when the arrow would otherwise run off the column.
                            Text {
                                id: presetNameText
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, parent.width - presetArrow.implicitWidth - 6)
                                text: root.eePreset || "EasyEffects"
                                color: presetNameMouse.containsMouse ? theme.mauve : theme.text
                                font.pixelSize: theme.fontSize
                                font.weight: Font.Medium
                                font.family: theme.font
                                elide: Text.ElideRight
                            }

                            Text {
                                id: presetArrow
                                anchors.left: presetNameText.right
                                anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.presetMenuOpen ? "\uf106" : "\uf107"   // nf-fa-angle_up / angle_down
                                color: presetNameMouse.containsMouse ? theme.mauve : theme.subtext0
                                font.pixelSize: theme.fontSize
                                font.family: theme.font
                            }

                            MouseArea {
                                id: presetNameMouse
                                anchors.left: presetNameText.left
                                anchors.right: presetArrow.right
                                anchors.top: presetNameText.top
                                anchors.bottom: presetNameText.bottom
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.presetMenuOpen = !root.presetMenuOpen
                                    if (root.presetMenuOpen && !eePresetListProc.running) eePresetListProc.running = true
                                }
                            }
                        }

                        // Always shown so the row height doesn't jump when the preset name arrives
                        Text {
                            text: root.eePreset ? "EasyEffects" : "No preset loaded"
                            color: theme.subtext0
                            font.pixelSize: theme.fontSizeMin
                            font.family: theme.font
                            Layout.fillWidth: true
                        }
                    }

                    // Repair silent playback (stalled EE chain / sink resume glitch)
                    Text {
                        text: repairProc.running ? "…" : "↻"
                        color: repairProc.running ? theme.overlay0 : theme.subtext0
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

    ColumnLayout {
                Layout.fillWidth: true
                visible: root.presetMenuOpen
                spacing: 2

                Repeater {
                    model: root.eePresets
                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool isCurrent: modelData === root.eePreset
                        Layout.fillWidth: true
                        implicitHeight: presetLabel.implicitHeight + 10
                        radius: theme.radiusMd
                        color: presetItemMouse.containsMouse ? theme.surface0 : "transparent"

                        Text {
                            id: presetLabel
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: (isCurrent ? "● " : "○ ") + modelData
                            color: isCurrent ? theme.mauve : theme.subtext0
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: presetItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.presetMenuOpen = false
                                // Reloading the current preset would discard unsaved EE edits; skip it.
                                if (isCurrent || eePresetLoadProc.running) return
                                root.eePreset = modelData   // optimistic; re-read after load
                                root.pendingPresetCmd = ["easyeffects", "-l", modelData]
                                eePresetLoadProc.running = true
                            }
                        }
                    }
                }

                Text {
                    visible: root.eePresets.length === 0
                    text: eePresetListProc.running ? "Loading presets…" : "No output presets"
                    color: theme.overlay0
                    font.pixelSize: theme.fontSize - 1
                    font.family: theme.font
                    Layout.leftMargin: 8
                }
            }
        }

        SectionCard {
            theme: root.theme
            title: "Input Device"

    ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: root.sources
                    delegate: DeviceRow {
                        required property var modelData
                        theme: root.theme
                        node: modelData
                        isInput: true
                        fillColor: theme.blue
                        isDefault: Pipewire.defaultAudioSource === modelData
                        onMakeDefault: Pipewire.preferredDefaultAudioSource = modelData
                    }
                }

                // Default input is a virtual source (e.g. EasyEffects' mic chain), not a device above.
                Text {
                    readonly property var src: Pipewire.defaultAudioSource
                    Layout.fillWidth: true
                    visible: !!src && root.sources.indexOf(src) < 0
                    text: src ? "Apps record from " + (src.description || src.name) : ""
                    color: theme.subtext0
                    font.pixelSize: theme.fontSizeMin
                    font.family: theme.font
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.sources.length === 0
                    text: "No input devices"
                    color: theme.subtext0
                    font.pixelSize: theme.fontSize - 1
                    font.family: theme.font
                }
            }
        }

        SectionCard {
            theme: root.theme
            title: "Applications" + (streamList.count > 0 ? " (" + streamList.count + ")" : "")
            Layout.fillHeight: true

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
                        id: streamRow
                        required property var modelData
                        readonly property var props: modelData.properties || {}
                        readonly property string appName: props["application.name"] || props["application.process.binary"] || ""
                        readonly property string mediaName: props["media.name"] || ""
                        readonly property bool muted: !!(modelData.audio && modelData.audio.muted)
                        spacing: 6
                        width: streamList.width

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            AppIcon {
                                appId: streamRow.appName
                                iconName: streamRow.props["application.icon_name"] || ""
                                fallbackIcon: "audio-x-generic"
                                size: 22
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    text: streamRow.appName || streamRow.mediaName || "Unknown"
                                    color: theme.text
                                    font.pixelSize: theme.fontSize
                                    font.family: theme.fontUi
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                // What it's playing (tab/track title), when it says more than the app name
                                Text {
                                    visible: text !== "" && text !== streamRow.appName
                                    text: streamRow.mediaName
                                    color: theme.subtext0
                                    font.pixelSize: theme.fontSizeMin
                                    font.family: theme.fontUi
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Text {
                                text: streamRow.muted ? "\ueee8" : "\uf028"
                                color: streamRow.muted ? theme.overlay0 : theme.subtext0
                                font.pixelSize: theme.fontSize
                                font.family: theme.font

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (streamRow.modelData.audio) streamRow.modelData.audio.muted = !streamRow.muted
                                }
                            }
                        }

                        VolumeSlider {
                            Layout.fillWidth: true
                            theme: root.theme
                            node: streamRow.modelData
                            fillColor: theme.volumeNormalColor
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

    onActiveChanged: {
        if (active) requestPreset()
        else presetMenuOpen = false
    }

    Process {
        id: eePresetListProc
        // Output: "Output presets:" then "N<TAB>name" lines, a blank line, then the input section.
        command: ["easyeffects", "-p"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [], inOutput = false
                this.text.split("\n").forEach(l => {
                    var t = l.trim()
                    if (/^Output presets:/i.test(t)) { inOutput = true; return }
                    if (/presets/i.test(t) && !/^\s*\d+\t/.test(l)) { inOutput = false; return }
                    var m = l.match(/^\s*\d+\t(.+)$/)
                    if (inOutput && m) out.push(m[1].trim())
                })
                root.eePresets = out
            }
        }
    }

    Process {
        id: eePresetLoadProc
        command: root.pendingPresetCmd
        onRunningChanged: if (!running) root.requestPreset()
    }

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

    // Devices/streams are live from Pipewire; only EasyEffects state is polled.
    Timer {
        interval: 4500
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!eeStatusProc.running) eeStatusProc.running = true
    }
}
