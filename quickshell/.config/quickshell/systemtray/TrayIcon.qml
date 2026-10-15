import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.common

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
            trayTip.suppressed = true
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

    }

    BarTooltip {
        id: trayTip
        readonly property string title: trayIcon.modelData.tooltipTitle !== "" ? trayIcon.modelData.tooltipTitle : trayIcon.modelData.title
        target: trayIcon
        hovered: trayMouse.containsMouse && title !== ""
        delay: 600

        Text {
            text: trayTip.title
            color: trayTip.theme.text
            font.pixelSize: trayTip.theme.fontSize - 1
            font.weight: Font.Medium
            font.family: trayTip.theme.font
            wrapMode: Text.Wrap
            Layout.maximumWidth: 320
        }
        Text {
            // SNI descriptions may carry markup; render as plain text.
            visible: text !== ""
            text: trayIcon.modelData.tooltipDescription
            textFormat: Text.PlainText
            color: trayTip.theme.subtext0
            font.pixelSize: trayTip.theme.fontSize - 2
            font.family: trayTip.theme.font
            wrapMode: Text.Wrap
            Layout.maximumWidth: 320
        }
    }
}
