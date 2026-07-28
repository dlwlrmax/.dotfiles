import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property Theme theme: Theme {}

    color: theme.surface1
    width: 1
    implicitHeight: 18
    Layout.alignment: Qt.AlignVCenter
}
