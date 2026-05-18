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
            id: trayDelegate
            required property var modelData
            implicitWidth: 14
            implicitHeight: 14
            color: "transparent"

            Image {
                anchors.fill: parent
                source: trayDelegate.modelData.icon
                sourceSize.width: 14
                sourceSize.height: 14
                fillMode: Image.PreserveAspectFit
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: trayDelegate.modelData.menu
                anchor.item: trayDelegate
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom | Edges.Right
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) {
                        trayDelegate.modelData.activate()
                    } else if (mouse.button === Qt.MiddleButton) {
                        trayDelegate.modelData.secondaryActivate()
                    } else if (mouse.button === Qt.RightButton) {
                        if (trayDelegate.modelData.hasMenu) {
                            menuAnchor.anchor.updateAnchor()
                            menuAnchor.open()
                        } else {
                            var win = trayDelegate.Window.window
                            var pos = trayDelegate.mapToItem(win.contentItem, mouse.x, mouse.y)
                            trayDelegate.modelData.display(win, pos.x, pos.y)
                        }
                    }
                }
                onWheel: wheel => {
                    trayDelegate.modelData.scroll(wheel.angleDelta.y, false)
                }
            }
        }
    }
}
