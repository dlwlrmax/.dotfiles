import QtQuick
import Quickshell
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property var dataSource: null
    property int notifCount: 0
    property bool dnd: dataSource ? dataSource.dnd : false
    signal togglePanel()

    onDataSourceChanged: {
        if (dataSource)
            notifCount = dataSource.count
    }

    Connections {
        target: dataSource
        ignoreUnknownSignals: true
        function onCountChanged() {
            root.notifCount = dataSource.count
        }
    }

    implicitWidth: iconText.implicitWidth
    implicitHeight: iconText.implicitHeight

    Text {
        id: iconText
        anchors.centerIn: parent
        text: root.dnd ? "\uF09B" : "\uF0F3"
        color: root.notifCount > 0 ? theme.white : theme.surface1
        font.pixelSize: theme.fontSize + 7
        font.weight: Font.Medium
        font.family: theme.font
    }

    Rectangle {
        id: badge
        visible: root.notifCount > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -1
        anchors.rightMargin: -3
        width: Math.max(12, badgeText.implicitWidth + 6)
        height: 12
        radius: 7
        color: theme.red

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: root.notifCount > 9 ? "9+" : root.notifCount
            color: theme.white
            font.pixelSize: 9
            font.bold: true
            font.family: theme.font
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.togglePanel();
            } else if (mouse.button === Qt.RightButton) {
                if (root.dataSource && root.dataSource.toggleDnd)
                    root.dataSource.toggleDnd();
            }
        }
    }
}
