import QtQuick

// Thin vertical gauge (0-100) for dense bar stats.
Rectangle {
    id: meter

    property Theme theme: ThemeStore
    property real value: 0
    property color clr: theme.green

    implicitWidth: 5
    implicitHeight: 16
    radius: 2
    color: theme.trackColor

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(value > 0 ? 2 : 0, parent.height * Math.min(meter.value, 100) / 100)
        radius: parent.radius
        color: meter.clr
        Behavior on height { NumberAnimation { duration: 200 } }
    }
}
