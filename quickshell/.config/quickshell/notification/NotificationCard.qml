import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Rectangle {
    id: root
    property Theme theme: Theme {}
    property var notifData: ({})
    property var onDismiss: null

    color: theme.surface0
    radius: 12
    height: content.implicitHeight + 16

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        Rectangle {
            width: 36
            height: 36
            radius: 18
            color: theme.surface1
            Layout.alignment: Qt.AlignTop

            Image {
                anchors.fill: parent
                anchors.margins: 6
                source: notifData.app_icon ? Quickshell.iconPath(notifData.app_icon) : ""
                visible: !!notifData.app_icon && source.toString().length > 0
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors.centerIn: parent
                text: ""
                color: theme.subtext0
                font.pixelSize: 16
                visible: !notifData.app_icon || parent.children[0].visible === false
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: notifData.app_name || "Unknown"
                color: theme.text
                font.pixelSize: theme.fontSize
                font.bold: true
                font.family: theme.font
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: notifData.summary || ""
                color: theme.text
                font.pixelSize: theme.fontSize
                font.family: theme.font
                Layout.fillWidth: true
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                visible: !!notifData.summary && notifData.summary.length > 0
            }

            Text {
                text: notifData.body || ""
                color: theme.subtext0
                font.pixelSize: theme.fontSize - 2
                font.family: theme.font
                Layout.fillWidth: true
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                visible: !!notifData.body && notifData.body.length > 0
            }
        }
    }

    Text {
        id: dismissBtn
        text: "×"
        color: theme.subtext0
        font.pixelSize: theme.fontSize + 2
        font.family: theme.font
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 4
        anchors.rightMargin: 10

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.onDismiss) root.onDismiss();
            }
        }
    }
}
