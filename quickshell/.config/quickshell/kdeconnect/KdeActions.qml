import QtQuick
import Quickshell.Io
import qs.common

// Non-visual: runs KDE Connect actions one at a time and reports a short status
// line ("Ping sent", "Reply failed", ...) for the panel to show.
Item {
    id: act

    property Theme theme: ThemeStore
    property var dataSource: null     // shared kdeData (for refresh / optimistic removal)
    property string status: ""
    property bool statusOk: true

    property var _jobs: []
    property var _current: null
    property string _pickDevice: ""

    function say(text, ok) {
        if (!text) return
        status = text
        statusOk = ok
        statusTimer.restart()
    }

    // cmd: argv array; after(code): optional callback; empty ok/fail texts stay quiet.
    function run(cmd, okText, failText, after) {
        _jobs = _jobs.concat([{ cmd: cmd, ok: okText, fail: failText, after: after || null }])
        _pump()
    }

    function _pump() {
        if (jobProc.running || _jobs.length === 0) return
        _current = _jobs[0]
        _jobs = _jobs.slice(1)
        jobProc.command = _current.cmd
        jobProc.running = true
    }

    function _cli(id, flag, ok, fail) {
        run(["kdeconnect-cli", "-d", id, flag], ok, fail)
    }

    function ring(id) { _cli(id, "--ring", "Ringing phone…", "Ring failed") }
    function ping(id) { _cli(id, "--ping", "Ping sent ✓", "Ping failed") }
    function sendClipboard(id) { _cli(id, "--send-clipboard", "Clipboard sent ✓", "Clipboard send failed") }
    function pair(id) { _cli(id, "--pair", "Pairing requested — accept on the phone", "Pairing failed") }
    function unpair(id) { _cli(id, "--unpair", "Unpaired", "Unpair failed") }

    function refreshDevices() {
        run(["kdeconnect-cli", "--refresh"], "Searching for devices…", "Refresh failed", function () {
            if (dataSource && dataSource.refresh) dataSource.refresh()
        })
    }

    // File chooser, then share the pick.
    function shareFile(id) {
        if (pickProc.running) return
        _pickDevice = id
        pickProc.running = true
    }

    // D-Bus activation starts kdeconnectd if its service file is installed.
    function startDaemon() {
        run(["dbus-send", "--session", "--dest=org.kde.kdeconnect", "--type=method_call",
             "/modules/kdeconnect", "org.freedesktop.DBus.Peer.Ping"],
            "Starting KDE Connect…", "Could not start the daemon", function (code) {
                if (code === 0) daemonRefresh.restart()
            })
    }

    function reply(devId, nid, msg) {
        run(["dbus-send", "--print-reply", "--dest=org.kde.kdeconnect",
             "/modules/kdeconnect/devices/" + devId + "/notifications/" + nid,
             "org.kde.kdeconnect.device.notifications.notification.sendReply",
             "string:" + msg], "Reply sent ✓", "Reply failed")
    }

    function dismiss(devId, nid) {
        if (dataSource && dataSource.dismissOptimistic) dataSource.dismissOptimistic(devId, nid)
        run(["bash", theme.scriptDir + "/kdeconnect.sh", "dismiss", devId, nid], "", "", function () {
            if (dataSource && dataSource.dismissOptimistic) dataSource.dismissOptimistic(devId, nid)
            if (dataSource && dataSource.refresh) dataSource.refresh()
        })
    }

    function dismissAll(devId) {
        if (dataSource && dataSource.clearOptimistic) dataSource.clearOptimistic(devId)
        run(["bash", theme.scriptDir + "/kdeconnect.sh", "dismiss-all", devId], "", "", function () {
            if (dataSource && dataSource.clearOptimistic) dataSource.clearOptimistic(devId)
            if (dataSource && dataSource.refresh) dataSource.refresh()
        })
    }

    Process {
        id: jobProc
        running: false
        stdout: StdioCollector { id: jobOut }

        onExited: code => {
            var job = act._current
            act._current = null
            if (job) {
                if (code === 0) act.say(job.ok, true)
                else act.say(job.fail, false)
                if (job.after) job.after(code)
            }
            act._pump()
        }
    }

    Process {
        id: pickProc
        running: false
        command: ["zenity", "--file-selection", "--title=Send to phone"]
        stdout: StdioCollector { id: pickOut }

        onExited: code => {
            var path = pickOut.text.trim()
            if (code !== 0 || !path) return
            var name = path.split("/").pop()
            act.run(["kdeconnect-cli", "-d", act._pickDevice, "--share", path],
                    "Sent " + name + " ✓", "Could not send " + name)
        }
    }

    Timer {
        id: statusTimer
        interval: 3500
        onTriggered: act.status = ""
    }

    Timer {
        id: daemonRefresh
        interval: 1500
        onTriggered: if (act.dataSource && act.dataSource.refresh) act.dataSource.refresh()
    }
}
