import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.common

// One output or input device: default radio, name, mute, volume slider.
ColumnLayout {
    id: row
    property Theme theme: Theme {}
    required property var node           // PwNode (tracked)
    property bool isDefault: false
    property bool isInput: false
    property color fillColor: theme.mauve
    signal makeDefault()

    readonly property bool muted: !!(node && node.audio && node.audio.muted)

    spacing: 6
    Layout.fillWidth: true

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: row.isDefault ? "◉" : "○"
            color: row.isDefault ? row.fillColor : row.theme.surface1
            font.pixelSize: row.theme.fontSize + 2

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: row.makeDefault()
            }
        }

        Text {
            text: row.node ? (row.node.description || row.node.nickname || row.node.name) : ""
            color: row.theme.text
            font.pixelSize: row.theme.fontSize
            font.weight: Font.Medium
            font.family: row.theme.font
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Text {
            // Input: microphone / microphone-slash. Output: volume-up / muted speaker.
            // nf-md-microphone_off / microphone (U+F036D / U+F036C as surrogate pairs)
            text: row.isInput ? (row.muted ? "\udb80\udf6d" : "\udb80\udf6c")
                              : (row.muted ? "" : "")
            color: row.muted ? row.theme.surface1 : row.theme.subtext0
            font.pixelSize: row.theme.fontSize
            font.family: row.theme.font

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: if (row.node && row.node.audio) row.node.audio.muted = !row.node.audio.muted
            }
        }
    }

    VolumeSlider {
        Layout.fillWidth: true
        theme: row.theme
        node: row.node
        fillColor: row.fillColor
    }
}
