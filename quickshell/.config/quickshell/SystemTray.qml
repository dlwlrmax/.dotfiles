import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

RowLayout {
    id: trayContainer
    spacing: 4

    Repeater {
        model: SystemTray.items

        delegate: Rectangle {
            required property var modelData
            implicitWidth: 14
            implicitHeight: 14
            color: "transparent"

            Image {
                anchors.fill: parent
                source: parent.modelData.icon
                sourceSize.width: 24
                sourceSize.height: 24
                fillMode: Image.PreserveAspectFit
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (mouse.button === Qt.LeftButton) {
                        parent.modelData.activate()
                    } else if (mouse.button === Qt.MiddleButton) {
                        parent.modelData.secondaryActivate()
                    }
                }
                onWheel: wheel => {
                    parent.modelData.scroll(wheel.angleDelta.y, false)
                }
            }
        }
    }
}
