// DepsCheck — warns about missing runtime packages (deps/deps.list).
// Runs once shortly after startup; the notification it posts carries an
// "Install" button (handled by scripts/check-deps.sh).
//   qs ipc call deps check     re-check now, report even when all is fine
// Plain list without UI: scripts/check-deps.sh --list
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: ThemeStore
    // Let the notification server and the rest of the session settle first.
    property int startDelayMs: 15000

    function check(verbose) {
        if (checkProc.running) return
        checkProc.command = ["bash", theme.scriptDir + "/check-deps.sh"].concat(verbose ? ["--verbose"] : [])
        checkProc.running = true
    }

    Process {
        id: checkProc
    }

    Timer {
        interval: root.startDelayMs
        running: true
        onTriggered: root.check(false)
    }

    IpcHandler {
        target: "deps"
        function check(): void { root.check(true) }
    }
}
