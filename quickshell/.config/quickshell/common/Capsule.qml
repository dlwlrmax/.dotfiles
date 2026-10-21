import QtQuick
import QtQuick.Layouts

// Rounded group behind related bar widgets. Children flow in a row.
Rectangle {
    id: capsule

    property Theme theme: ThemeStore
    default property alias content: row.data
    property alias spacing: row.spacing

    implicitWidth: row.implicitWidth + 20
    implicitHeight: 30
    radius: theme.radiusLg
    color: theme.capsuleColor
    Layout.alignment: Qt.AlignVCenter

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8
    }
}
