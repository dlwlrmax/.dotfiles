import QtQuick

// Small square glyph button with a hover highlight (panel headers).
Rectangle {
    id: btn

    property Theme theme
    property string text: ""
    property int glyphSize: theme.fontSize + 2
    // Glyph colour override (e.g. an "on" state); transparent = default hover colouring.
    property color tint: "transparent"
    // Solid accent fill (play button).
    property color fill: "transparent"
    signal clicked()

    implicitWidth: 24
    implicitHeight: 24
    radius: theme.radiusSm
    color: fill.a > 0 ? (ma.containsMouse ? Qt.lighter(fill, 1.1) : fill)
         : ma.pressed ? theme.surface1 : ma.containsMouse ? theme.surface0 : "transparent"
    opacity: enabled ? 1 : 0.35
    scale: ma.pressed ? 0.92 : 1
    Behavior on scale { SpringAnimation { spring: btn.theme.springPress; damping: btn.theme.dampingPress; epsilon: btn.theme.epsilonPress } }
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
        anchors.centerIn: parent
        text: btn.text
        color: btn.fill.a > 0 ? btn.theme.base : btn.tint.a > 0 ? btn.tint : ma.containsMouse ? btn.theme.text : btn.theme.subtext0
        font.pixelSize: btn.glyphSize
        font.family: btn.theme.font
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
