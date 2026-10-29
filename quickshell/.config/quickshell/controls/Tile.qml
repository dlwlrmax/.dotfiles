import QtQuick
import QtQuick.Layouts
import qs.common

// One quick-toggle tile: glyph, label and state text; tinted while active.
Rectangle {
    id: tile

    property Theme theme: ThemeStore
    property string icon: ""
    property string label: ""
    property string state: ""
    property bool active: false
    property color clr: theme.blue
    signal clicked()

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.columnSpan: 1
    implicitHeight: 78
    radius: theme.radiusLg
    color: active ? Qt.alpha(clr, ma.containsMouse ? 0.28 : 0.18)
                  : Qt.alpha(theme.surface0, ma.containsMouse ? 0.8 : 0.45)
    border.width: 1
    border.color: active ? Qt.alpha(clr, 0.5) : "transparent"
    scale: ma.pressed ? 0.97 : 1
    Behavior on scale { SpringAnimation { spring: theme.springPress; damping: theme.dampingPress; epsilon: theme.epsilonPress } }
    Behavior on color { ColorAnimation { duration: 120 } }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 0

        Text {
            text: tile.icon
            color: tile.active ? tile.clr : tile.theme.subtext0
            font.pixelSize: tile.theme.fontSize + 9
            font.family: tile.theme.font
        }

        Item { Layout.fillHeight: true }

        Text {
            text: tile.label
            color: tile.theme.text
            font.pixelSize: tile.theme.fontSize - 1
            font.bold: true
            font.family: tile.theme.fontUi
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Text {
            text: tile.state
            color: tile.active ? tile.clr : tile.theme.subtext0
            font.pixelSize: tile.theme.fontSizeMin
            font.family: tile.theme.fontUi
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.clicked()
    }
}
