import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property var dataSource: null
    property string dlText: dataSource ? dataSource.dlText : "--"
    property string ulText: dataSource ? dataSource.ulText : "--"
    signal togglePanel()

    // Hard containment: layout squeeze must never paint over neighbors.
    clip: true
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    Column {
        id: col
        spacing: 0
        width: 50

        RowLayout {
            spacing: 2
            width: parent.width

            Text {
                text: ""
                color: root.theme.subtext0
                font.pixelSize: root.theme.fontSize
                font.weight: Font.Medium
            }

            Text {
                text: root.dlText
                color: root.theme.subtext0
                font.pixelSize: root.theme.fontSize - 2
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        RowLayout {
            spacing: 2
            width: parent.width

            Text {
                text: ""
                color: root.theme.subtext0
                font.pixelSize: root.theme.fontSize
                font.weight: Font.Medium
            }

            Text {
                text: root.ulText
                color: root.theme.subtext0
                font.pixelSize: root.theme.fontSize - 2
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.togglePanel()
            }
        }
    }
}
