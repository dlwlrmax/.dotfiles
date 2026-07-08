import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.common

Item {
    id: root

    property string icon: ""
    property int level: 0
    property bool muted: false
    property int autoHideMs: 1500

    readonly property Theme theme: Theme {}
    readonly property string accentColor: root.muted ? theme.surface1 : (root.level > 80 ? theme.red : root.level > 50 ? theme.yellow : root.level > 30 ? theme.peach : theme.green)

    implicitWidth: osdRow.implicitWidth + 32
    implicitHeight: osdRow.implicitHeight + 16
    opacity: 0

    property int _changeSeq: 0
    onLevelChanged: { _changeSeq++; _show() }
    onMutedChanged: { _changeSeq++; _show() }

    function _show() {
        var seq = _changeSeq
        root.opacity = 1.0
        hideTimer.restart()
        hideTimer._activeSeq = seq
    }

    Timer {
        id: hideTimer
        property int _activeSeq: 0
        interval: root.autoHideMs
        onTriggered: {
            if (_activeSeq === root._changeSeq) {
                root.opacity = 0.0
            }
        }
    }

    Behavior on opacity {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: osdCard
        anchors.fill: parent
        radius: 12
        color: root.theme.surface0
        opacity: 0.95

        RowLayout {
            id: osdRow
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: root.icon
                color: root.muted ? root.theme.surface1 : root.accentColor
                font.family: root.theme.font
                font.pixelSize: root.theme.fontSize + 8
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 8
                Layout.alignment: Qt.AlignVCenter
                radius: 4
                color: root.theme.surface1

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * (root.level / 100.0)
                    radius: 4
                    color: root.muted ? root.theme.surface1 : root.accentColor
                }
            }

            Text {
                text: root.muted ? "Muted" : root.level + "%"
                color: root.muted ? root.theme.surface1 : root.theme.text
                font.family: root.theme.font
                font.pixelSize: root.theme.fontSize
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignVCenter
                Layout.minimumWidth: root.muted ? 42 : 34
            }
        }
    }
}
