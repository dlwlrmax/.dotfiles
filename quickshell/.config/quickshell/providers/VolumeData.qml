// VolumeData
// Default output volume/mute straight from Pipewire (no polling).
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import QtQuick
import qs.common

Item {
    id: volumeData
    property Theme theme: ThemeStore
    // Poll period; DataProviders slows it down while gaming.
    property int statPollMs: 2000
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property int volumeLevel: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    // Microphone: the default input when it exposes audio controls; otherwise (e.g. a
    // virtual EasyEffects source) the first physical input, so mute still works.
    // Properties/audio are only populated for tracked nodes, so track them all.
    PwObjectTracker { objects: Pipewire.nodes.values }
    readonly property var _inputs: Pipewire.nodes.values.filter(function (n) {
        var p = n.properties || {}
        return n.audio && !n.isSink && !n.isStream && (p["device.api"] === "alsa" || !!p["device.bus"])
    })
    readonly property var source: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio
        ? Pipewire.defaultAudioSource : (_inputs.length > 0 ? _inputs[0] : null)
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false
    PwObjectTracker { objects: [volumeData.source] }
    function toggleMic() {
        if (source && source.audio) source.audio.muted = !source.audio.muted
    }
    // Last known default sink name. Only updated with non-empty names so a
    // transient null during a switch doesn't look like a change.
    property string defaultSink: ""
    property var _notifyCmd: []
    property var _pendingNotifyCmd: []
    // True while an explicit cycleSink() is in flight. Suppresses the
    // sink-change notify so a cycle never produces two popups (the script
    // already notifies itself once).
    property bool _cycling: false

    function toggleMute() {
        if (sink && sink.audio) sink.audio.muted = !sink.audio.muted
    }

    // 5% notches; see VolumeStep.target for snapping/capping.
    function stepVolume(steps) {
        if (!sink || !sink.audio) return
        sink.audio.volume = VolumeStep.target(sink.audio.volume, steps)
    }

    function cycleSink() {
        if (!cycleProc.running) {
            volumeData._cycling = true
            cycleProc.running = true
        }
    }

    // Audio params (volume/mute) are only populated for tracked nodes.
    PwObjectTracker { objects: [volumeData.sink] }

    onSinkChanged: {
        var name = sink ? sink.name : ""
        if (name === "") return
        // Notify on external switches too (panel/hotkey/Bluetooth).
        // Cycle path notifies itself.
        if (_eeSink !== "" && name !== _eeSink) eeBypassSwitch(_eeSink, name)
        _eeSink = name
        if (defaultSink !== "" && name !== defaultSink && !_cycling) {
            var notifyCmd = [theme.scriptDir + "/audio-notify.sh", name]
            if (!switchNotifyProc.running) {
                _notifyCmd = notifyCmd
                switchNotifyProc.running = true
            } else {
                _pendingNotifyCmd = notifyCmd
            }
        }
        defaultSink = name
    }

    // EasyEffects on/off is global; remember it per output device. On a switch,
    // read the state in use (it belongs to the output we're leaving), save it,
    // and apply what was saved for the new output (if anything).
    property var _eeBySink: {
        var row = Db.cacheGet("ee_bypass_by_sink")
        try { return row ? JSON.parse(row.json) : {} } catch (e) { return {} }
    }
    property string _eeLeaving: ""
    property string _eeSink: ""        // output the EE state currently belongs to
    property var _eePending: null      // { from, to } queued while a switch runs

    function eeBypassSwitch(fromSink, toSink) {
        if (eeSwitchProc.running) {
            // A→B still running, then B→C (→D…): run one B→(latest) afterwards.
            if (_eePending) _eePending.to = toSink
            else _eePending = { from: fromSink, to: toSink }
            return
        }
        _eeLeaving = fromSink
        eeSwitchProc.wanted = _eeBySink[toSink] || ""
        eeSwitchProc.running = true
    }

    Process {
        id: eeSwitchProc
        property string wanted: ""   // "1" = bypassed (effects off), "2" = effects on, "" = leave as is
        command: ["sh", "-c",
            "pgrep -x easyeffects >/dev/null || exit 0; "
            + "echo \"cur=$(timeout 4 easyeffects -b 3 | grep -E '^[12]$' | tail -1)\"; "
            + "[ -n \"$1\" ] && timeout 4 easyeffects -b \"$1\"; true",
            "sh", wanted]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = (this.text || "").match(/cur=([12])/)
                if (!m || volumeData._eeLeaving === "") return
                var map = Object.assign({}, volumeData._eeBySink)
                map[volumeData._eeLeaving] = m[1]
                volumeData._eeBySink = map
                Db.cachePut("ee_bypass_by_sink", JSON.stringify(map))
            }
        }
        onRunningChanged: {
            if (running || !volumeData._eePending) return
            var next = volumeData._eePending
            volumeData._eePending = null
            if (next.from !== next.to) volumeData.eeBypassSwitch(next.from, next.to)
        }
    }

    Process {
        id: cycleProc
        command: [theme.scriptDir + "/audio-cycle.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Script notifies itself; sync baseline so the sink change stays silent
                var sink = this.text.trim().split("\n").filter(function (l) { return l !== ""; }).pop() || "";
                if (sink !== "") volumeData.defaultSink = sink;
            }
        }
        onRunningChanged: {
            // Pipewire may report the new default slightly after the script exits;
            // hold the gate briefly so that late change doesn't notify twice.
            if (!running) cycleGateTimer.restart()
        }
    }

    Timer {
        id: cycleGateTimer
        interval: 500
        onTriggered: volumeData._cycling = false
    }

    Process {
        id: switchNotifyProc
        command: volumeData._notifyCmd
        onRunningChanged: {
            if (!running && volumeData._pendingNotifyCmd.length > 0) {
                volumeData._notifyCmd = volumeData._pendingNotifyCmd;
                volumeData._pendingNotifyCmd = [];
                running = true;
            }
        }
    }
}
