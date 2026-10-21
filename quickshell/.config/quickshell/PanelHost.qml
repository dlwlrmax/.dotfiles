import Quickshell
import QtQuick
import qs.common

// One popup panel window. Open state comes from the Panels singleton, so a panel
// needs only its name and a placement:
//   placement: "right"   hangs under the bar's right side (net, sysUsage, tray, ...)
//              "widget"  centred under the bar widget that opened it
//              "center"  centred on screen, over everything (power, launcher, clipboard)
// `panel` is a Component for the panel itself (anchors.fill: parent, onClose: Panels.close()).
// It is built only while the window is on screen (open + the close fade) and destroyed after, so
// closed panels cost nothing. The loaded panel's `active` is bound to the host's, and it flips
// false -> true on creation, so `onActiveChanged` is the place for open-time work.
PanelOverlay {
    id: host

    required property var targetScreen      // the screen this instance belongs to
    required property string name
    property string placement: "right"
    property Component panel: null

    screen: targetScreen
    active: Panels.isOpen(name, targetScreen.name)
    onCloseRequested: Panels.close()
    topMargin: placement === "center" ? 0 : ThemeStore.barHeight
    position: placement === "center" ? PanelOverlay.Position.Center
            : placement === "widget" ? PanelOverlay.Position.TopCenter
            : PanelOverlay.Position.TopRight
    centerOffset: Panels.centerOf(name, targetScreen.name, targetScreen.width) - targetScreen.width / 2

    Loader {
        active: host.visible
        // The panel fills its Loader (anchors.fill: parent), so the Loader must take its size
        // from the panel's implicit size, or both end up 0x0.
        width: item ? item.implicitWidth : 0
        height: item ? item.implicitHeight : 0
        sourceComponent: host.panel
        onLoaded: {
            item.active = Qt.binding(function () { return host.active })
            host.keyTarget = item
        }
        onActiveChanged: if (!active) host.keyTarget = null
    }
}
