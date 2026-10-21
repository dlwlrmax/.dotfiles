import QtQuick

// Small rounded label. `solid` fills with the color; otherwise a tinted pill.
// Set `clickable` and handle clicked() for copy-style actions.
Rectangle {
    id: badge

    property Theme theme
    property string text: ""
    property color clr: theme.subtext0
    property bool solid: false
    property bool clickable: false
    property int pixelSize: theme.fontSizeMin
    signal clicked()

    implicitWidth: label.implicitWidth + 14
    implicitHeight: 20
    radius: theme.radiusMd
    color: solid ? clr : Qt.alpha(clr, clickable && ma.containsMouse ? 0.28 : 0.16)
    scale: clickable && ma.pressed ? 0.95 : 1
    Behavior on scale { NumberAnimation { duration: 80 } }
    border.width: solid ? 0 : 1
    border.color: Qt.alpha(clr, 0.35)

    Text {
        id: label
        anchors.centerIn: parent
        text: badge.text
        color: badge.solid ? badge.theme.base : badge.clr
        font.pixelSize: badge.pixelSize
        font.bold: badge.solid
        font.family: badge.theme.font
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: badge.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: badge.clicked()
    }
}
