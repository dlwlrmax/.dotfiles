import QtQuick
import QtQuick.Layouts
import qs.common

Item {
    property Theme theme: Theme {}
    id: root
    signal togglePanel()
    implicitWidth: clock.implicitWidth
    implicitHeight: clock.implicitHeight

    Text {
        id: clock
        color: theme.text
        font.pixelSize: theme.fontSize
        font.family: theme.font
        font.bold: true

        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                var d = new Date();
                var hh = ("0" + d.getHours()).slice(-2);
                var mm = ("0" + d.getMinutes()).slice(-2);
                var dd = ("0" + d.getDate()).slice(-2);
                var MM = ("0" + (d.getMonth() + 1)).slice(-2);
                clock.text = hh + ":" + mm + " " + dd + "/" + MM;
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
