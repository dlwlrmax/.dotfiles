pragma Singleton
import QtQuick

// Shell-wide flags that leaf components need without threading props through
// every parent. Written by shell.qml only.
QtObject {
    // Monitor the game is on while the gaming profile is active; "" when not gaming,
    // "*" when gaming but the monitor is unknown (blocks every screen).
    property string gamingMonitor: ""

    // True if popups/tooltips should stay off the given screen (QScreen/monitor name).
    function quietOn(screenName) {
        return gamingMonitor === "*" || (gamingMonitor !== "" && gamingMonitor === screenName)
    }
}
