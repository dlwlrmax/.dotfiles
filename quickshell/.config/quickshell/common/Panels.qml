pragma Singleton
import QtQuick

// Which popup panel is open, on which screen, and where the widget that opened it
// sits. At most one panel is open at a time. Panel names: notif, mpris, volume,
// weather, calendar, sysUsage, power, battery, net, kde, launcher, clipboard, tray,
// settings (quick toggles + preferences), wallpaper, browserPick.
QtObject {
    property string openName: ""
    property string screenName: ""
    // "name@screen" -> window-space x of the opening widget's centre
    property var centers: ({})

    function isOpen(name, screen) { return openName === name && screenName === screen }

    function toggle(name, screen, centerX) {
        if (isOpen(name, screen)) { close(); return }
        if (centerX > 0) {
            var c = Object.assign({}, centers)
            c[name + "@" + screen] = centerX
            centers = c
        }
        screenName = screen
        openName = name
    }

    function close() { openName = ""; screenName = "" }

    // Centre to anchor a panel on: the last widget click, else the screen centre.
    function centerOf(name, screen, screenWidth) {
        return centers[name + "@" + screen] || screenWidth / 2
    }
}
