import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray

RowLayout {
    id: trayContainer
    spacing: 2

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
                source: {
                    var icon = trayDelegate.modelData.icon
                    if (!icon) return ""
                    // Direct path/URL — use as-is
                    if (icon.charAt(0) === '/' || icon.startsWith("file:") || icon.startsWith("http:") || icon.startsWith("https:") || icon.startsWith("qrc:") || icon.startsWith("data:"))
                        return icon
                    // Quickshell pixmap provider — use as-is
                    if (icon.startsWith("image://qspixmap/"))
                        return icon
                    // image://icon/<name> — extract name, resolve via iconPath
                    if (icon.startsWith("image://icon/")) {
                        var iconName = icon.substring("image://icon/".length)
                        if (!iconName) return ""
                        // Extracted name might be a direct path (e.g. ///run/user/...)
                        if (iconName.charAt(0) === '/') return "file://" + iconName
                        var r = Quickshell.iconPath(iconName, true)
                        if (r !== "") return r
                        // Fallback: try direct hicolor path (for icons not in current theme)
                        return "file:///usr/share/icons/hicolor/scalable/status/" + iconName + ".svg"
                    }
                    // Plain themed icon name — resolve via Quickshell.iconPath
                    var r = Quickshell.iconPath(icon, true)
                    if (r !== "") return r
                    return ""
                }
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
                hoverEnabled: true
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

                ToolTip {
                    visible: parent.containsMouse && (trayDelegate.modelData.tooltipTitle !== "" || trayDelegate.modelData.title !== "")
                    text: {
                        let title = trayDelegate.modelData.tooltipTitle !== "" ? trayDelegate.modelData.tooltipTitle : trayDelegate.modelData.title
                        if (trayDelegate.modelData.tooltipDescription !== "")
                            return title + "\n" + trayDelegate.modelData.tooltipDescription
                        return title
                    }
                    delay: 800
                    font.pixelSize: 10
                }
            }
        }
    }
}
