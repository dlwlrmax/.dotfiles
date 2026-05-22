import QtQuick
import QtQuick.Layouts

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
            onTriggered: clock.text = new Date().toLocaleString(Qt.locale(), "hh:mm dd/MM");
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
