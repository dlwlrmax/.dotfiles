pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Shared media helpers for the bar widget, panel, tooltip and track toast.
Singleton {
    id: root

    // ── Track duration ──────────────────────────────────────
    // Zen/Firefox drop mpris:length from re-sent metadata (duration flickers away
    // mid-play) or never send it. Remember the last real length per player+track,
    // and for YouTube URLs ask yt-dlp once (if installed).

    property var _lengths: ({})       // trackKey -> seconds
    property var _fetchState: ({})    // url -> "pending" | "done"
    // Bumped when an async length arrives so bindings calling trackLength re-run.
    property int lengthsVersion: 0

    function trackUrl(p) {
        return p && p.metadata ? (p.metadata["xesam:url"] || "") : ""
    }
    function trackKey(p) {
        return (p.dbusName || p.identity || "") + "|" + (trackUrl(p) || p.trackTitle || "")
    }

    // Seconds, or 0 when unknown. Safe to call from bindings.
    function trackLength(p) {
        if (!p) return 0
        lengthsVersion   // dependency: re-evaluate when yt-dlp results land
        var key = trackKey(p)
        if (p.lengthSupported && p.length > 1) {
            _lengths[key] = p.length
            return p.length
        }
        if (_lengths[key]) return _lengths[key]
        var vid = youtubeId(trackUrl(p))
        if (vid) {
            var known = _lengths["yt|" + vid]
            if (known) return known
            Qt.callLater(root._requestYoutube, vid)
        }
        return 0
    }

    // Canonical video id from youtube.com/watch?v=, youtu.be/, /shorts/; "" otherwise.
    function youtubeId(url) {
        if (!url) return ""
        var m = url.match(/^https?:\/\/(?:www\.|m\.|music\.)?youtube\.com\/(?:watch\?(?:.*&)?v=|shorts\/)([\w-]{11})/)
            || url.match(/^https?:\/\/youtu\.be\/([\w-]{11})/)
        return m ? m[1] : ""
    }

    property var _ytQueue: []
    function _requestYoutube(vid) {
        if (_fetchState[vid]) return
        _fetchState[vid] = "pending"
        _ytQueue = _ytQueue.concat([vid])
        _runNextYoutube()
    }
    function _runNextYoutube() {
        if (ytProc.running || _ytQueue.length === 0) return
        ytProc.vid = _ytQueue[0]
        _ytQueue = _ytQueue.slice(1)
        ytProc.running = true
    }

    Process {
        id: ytProc
        property string vid: ""
        // Exits quietly when yt-dlp isn't installed; one network call per video id.
        command: ["sh", "-c",
            "command -v yt-dlp >/dev/null || exit 0; "
            + "echo \"vid=$1\"; "
            + "timeout 20 yt-dlp --no-warnings --skip-download --no-playlist --print duration -- \"https://www.youtube.com/watch?v=$1\"",
            "sh", vid]
        stdout: StdioCollector {
            onStreamFinished: {
                // The id comes from the output itself: exit and stream-finish order
                // can't attribute a duration to the next queued video.
                var lines = (this.text || "").trim().split("\n")
                var m = (lines[0] || "").match(/^vid=([\w-]{11})$/)
                var secs = parseFloat(lines[lines.length - 1])
                if (m && secs > 1) {
                    root._lengths["yt|" + m[1]] = secs
                    root.lengthsVersion++
                }
            }
        }
        onRunningChanged: {
            if (running) return
            root._fetchState[vid] = "done"
            Qt.callLater(root._runNextYoutube)
        }
    }

    // m:ss; "--:--" for missing/invalid values (unsupported position etc.).
    function formatTime(seconds) {
        if (seconds === undefined || seconds === null || isNaN(seconds) || seconds < 0) return "--:--"
        var t = Math.floor(seconds), m = Math.floor(t / 60), sec = t % 60
        return m + ":" + (sec < 10 ? "0" : "") + sec
    }

    // ── Current track / track changes ───────────────────────
    // Same rule as the bar widget: first player that is playing a titled track.
    readonly property var playing: (Mpris.players.values || []).find(p => p && p.isPlaying && p.trackTitle) ?? null
    readonly property string _nowKey: playing ? playing.trackTitle + "\u0000" + (playing.trackArtist || "") : ""
    property string _lastKey: ""
    property bool _armed: false

    // Emitted when a different track starts playing (not on pause/resume of the same one,
    // and not for whatever was already playing when the shell started).
    signal trackStarted(var player)

    on_NowKeyChanged: {
        if (_nowKey === "") return             // paused/stopped: keep _lastKey
        if (_armed && _nowKey !== _lastKey) trackStarted(playing)
        _lastKey = _nowKey
    }

    Timer {
        // Players restore their state right after startup; don't toast those.
        interval: 3000
        running: true
        onTriggered: { root._lastKey = root._nowKey || root._lastKey; root._armed = true }
    }
}
