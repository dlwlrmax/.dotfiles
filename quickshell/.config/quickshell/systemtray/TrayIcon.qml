import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray

// Shared tray icon delegate. Used inline in bar row + overflow popup grid.
Rectangle {
    id: trayIcon
    required property var modelData
    // Injected by Repeater. Without this declaration, delegate-site bindings
    // like `visible: index < n` do not resolve (verified on Qt 6.11).
    required property int index
    property int boxSize: 18
    signal activated()

    implicitWidth: boxSize
    implicitHeight: boxSize
    color: "transparent"
    opacity: trayMouse.containsPress ? 0.55 : 1.0
    Behavior on opacity { NumberAnimation { duration: 80 } }

    // Memoize iconPath(). Misses (out === "") NOT cached — late theme load retries.
    property var _iconCache: ({})
    function resolveIcon(icon) {
        if (!icon)
            return "";
        if (icon.charAt(0) === '/' || icon.startsWith("file:") || icon.startsWith("http:") || icon.startsWith("https:") || icon.startsWith("qrc:") || icon.startsWith("data:"))
            return icon;
        if (icon.startsWith("image://qspixmap/"))
            return icon;
        // Native provider handles theme lookup best — keep as-is unless
        // embedded path (e.g. image://icon///run/user/...).
        if (icon.startsWith("image://icon/")) {
            var iconName = icon.substring("image://icon/".length);
            if (iconName && iconName.charAt(0) === '/')
                return "file://" + iconName;
            return icon;
        }
        var cached = trayIcon._iconCache[icon];
        if (cached !== undefined)
            return cached;
        var out = Quickshell.iconPath(icon, true);
        if (out === "")
            return "";
        var keys = Object.keys(trayIcon._iconCache);
        if (keys.length > 128)
            trayIcon._iconCache = ({});
        trayIcon._iconCache[icon] = out;
        return out;
    }

    Image {
        anchors.centerIn: parent
        width: 14
        height: 14
        source: trayIcon.resolveIcon(trayIcon.modelData.icon)
        sourceSize.width: 28
        sourceSize.height: 28
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        mipmap: true
    }

    QsMenuAnchor {
        id: menuAnchor
        menu: trayIcon.modelData.menu
        anchor.item: trayIcon
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom | Edges.Right
    }

    MouseArea {
        id: trayMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                trayIcon.modelData.activate()
                trayIcon.activated()
            } else if (mouse.button === Qt.MiddleButton) {
                trayIcon.modelData.secondaryActivate()
            } else if (mouse.button === Qt.RightButton) {
                if (trayIcon.modelData.hasMenu) {
                    menuAnchor.anchor.updateAnchor()
                    menuAnchor.open()
                } else {
                    var win = trayIcon.Window.window
                    var pos = trayIcon.mapToItem(win.contentItem, mouse.x, mouse.y)
                    trayIcon.modelData.display(win, pos.x, pos.y)
                }
            }
        }
        onWheel: wheel => {
            trayIcon.modelData.scroll(wheel.angleDelta.y, false)
        }

        ToolTip {
            visible: trayMouse.containsMouse && (trayIcon.modelData.tooltipTitle !== "" || trayIcon.modelData.title !== "")
            text: {
                let title = trayIcon.modelData.tooltipTitle !== "" ? trayIcon.modelData.tooltipTitle : trayIcon.modelData.title
                if (trayIcon.modelData.tooltipDescription !== "")
                    return title + "\n" + trayIcon.modelData.tooltipDescription
                return title
            }
            delay: 1000
            font.pixelSize: 10
        }
    }
}
