import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

// Clipboard history (cliphist) on top of PickerPanel: thumbnails and a full
// preview, multi-word search, pins, delete, and paste-into-previous-window.
Item {
    id: root

    property Theme theme: ThemeStore
    property bool active: false
    signal close()

    implicitWidth: picker.implicitWidth
    implicitHeight: picker.implicitHeight

    property var allEntries: []            // [{id, content, isImage, label}]
    property var pins: []                  // [{key, text}] kept outside cliphist's own cap
    property var thumbs: ({})              // id -> decoded image file
    property string previewText: ""
    property string previewImage: ""
    property bool confirmWipe: false
    property string notice: ""
    readonly property int maxRows: 200

    // ── helpers ──

    function fold(s) {
        var out = ""
        for (var i = 0; i < s.length; i++) {
            var d = s.charAt(i).normalize("NFD").charAt(0)
            out += (d === "đ" || d === "Đ") ? "d" : d.toLowerCase()
        }
        return out
    }

    function oneLine(text) {
        var s = text.replace(/\s+/g, " ").trim()
        return s.length > 110 ? s.substring(0, 109) + "…" : s
    }

    function domainOf(text) {
        var m = /^https?:\/\/([^\/\s?#]+)/i.exec(text.trim())
        return m ? m[1].replace(/^www\./, "") : ""
    }

    // "[[ binary data 17 KiB png 350x195 ]]" -> "image · png 350×195 · 17 KiB"
    function imageInfo(label) {
        var m = /binary data ([\d.]+ \w+) (\w+) (\d+)x(\d+)/.exec(label)
        return m ? "image · " + m[2] + " " + m[3] + "×" + m[4] + " · " + m[1] : "image"
    }

    function toRow(e) {
        if (e.isImage) {
            return { kind: "entry", entry: e, title: "Image", subtitle: imageInfo(e.content),
                     glyph: "", thumb: root.thumbs[e.id] || "" }
        }
        var dom = domainOf(e.content)
        return { kind: "entry", entry: e, title: oneLine(e.content),
                 subtitle: dom ? "link · " + dom : "text",
                 glyph: dom ? "" : "" }
    }

    function pinRow(p) {
        return { kind: "pin", pin: p, title: oneLine(p.text), subtitle: "pinned",
                 glyph: "", glyphClr: theme.yellow, tag: "pin" }
    }

    // Every whitespace-separated word must appear (accent/case-insensitive);
    // if nothing matches that way, fall back to an in-order letter match.
    function matches(hay, words, fuzzy) {
        if (!fuzzy) {
            for (var i = 0; i < words.length; i++) if (hay.indexOf(words[i]) === -1) return false
            return true
        }
        var q = words.join(""), ni = 0
        for (var k = 0; k < q.length; k++) {
            var idx = hay.indexOf(q.charAt(k), ni)
            if (idx === -1) return false
            ni = idx + 1
        }
        return true
    }

    function rebuild() {
        var q = fold(picker.query.trim())
        var rows = []

        if (!q) {
            if (root.pins.length > 0) {
                rows.push({ isHeader: true, label: "Pinned" })
                root.pins.forEach(function (p) { rows.push(pinRow(p)) })
                rows.push({ isHeader: true, label: "History" })
            }
            root.allEntries.slice(0, root.maxRows).forEach(function (e) { rows.push(toRow(e)) })
            picker.rows = rows
            picker.status = root.allEntries.length + " items"
            picker.emptyText = root.allEntries.length === 0 && root.pins.length === 0 ? "clipboard is empty" : ""
            return
        }

        var words = q.split(/\s+/)
        for (var pass = 0; pass < 2 && rows.length === 0; pass++) {
            var fuzzy = pass === 1
            root.pins.forEach(function (p) {
                if (matches(fold(p.text), words, fuzzy)) rows.push(pinRow(p))
            })
            for (var i = 0; i < root.allEntries.length && rows.length < root.maxRows; i++) {
                var e = root.allEntries[i]
                var hay = e.isImage ? "image " + fold(e.content) : fold(e.content)
                if (matches(hay, words, fuzzy)) rows.push(toRow(e))
            }
        }
        picker.rows = rows
        picker.status = rows.length + " / " + (root.allEntries.length + root.pins.length)
        picker.emptyText = "no matches"
    }

    // Keep the cursor near where it was after a deletion.
    function rebuildKeeping(index) {
        rebuild()
        var n = picker.rows.length
        if (n === 0) return
        var i = Math.min(index, n - 1)
        while (i > 0 && picker.rows[i].isHeader) i--
        picker.selectedIndex = i
    }

    // ── data ──

    function load() {
        if (!listProc.running) listProc.running = true
        if (!imgProc.running) imgProc.running = true
    }

    function loadPins() {
        var row = Db.cacheGet("clippins")
        if (!row) return
        try { root.pins = JSON.parse(row.json) } catch (e) { root.pins = [] }
    }

    function savePins(list) {
        root.pins = list
        Db.cachePut("clippins", JSON.stringify(list))
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n"), entries = []
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i]
                    if (!line) continue
                    var tab = line.indexOf("\t")
                    if (tab < 0) continue
                    var content = line.substring(tab + 1).replace(/^---\s+/, "")
                    entries.push({ id: line.substring(0, tab), content: content,
                                   isImage: /^\[\[\s*binary/.test(content) })
                }
                root.allEntries = entries
                root.rebuild()
            }
        }
    }

    // Decoded image files for thumbnails/preview ("id<TAB>path" lines).
    Process {
        id: imgProc
        command: ["bash", theme.scriptDir + "/clip-images.sh", "24"]

        stdout: StdioCollector {
            onStreamFinished: {
                var map = ({}), lines = this.text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var t = lines[i].split("\t")
                    if (t.length === 2) map[t[0]] = t[1]
                }
                root.thumbs = map
                root.rebuild()
                root.requestPreview()
            }
        }
    }

    // Full text of the selected entry for the preview pane. One decode at a time: the id
    // a run was started for is kept, and a newer selection is picked up when it ends.
    Process {
        id: decodeProc
        property string runId: ""
        stdout: StdioCollector {
            onStreamFinished: {
                var want = picker.current && picker.current.entry ? String(picker.current.entry.id) : ""
                if (decodeProc.runId === want)
                    root.previewText = this.text.length > 8000 ? this.text.substring(0, 8000) + "\n\u2026" : this.text
            }
        }
        onExited: {
            var want = picker.current && picker.current.entry && !picker.current.entry.isImage
                       ? String(picker.current.entry.id) : ""
            if (want !== "" && want !== runId) root.startDecode(want)
        }
    }

    function startDecode(id) {
        decodeProc.runId = id
        decodeProc.command = ["cliphist", "decode", id]
        decodeProc.running = true
    }

    function requestPreview() {
        var r = picker.current
        root.previewImage = ""
        if (!r || r.isHeader) { root.previewText = ""; return }
        if (r.kind === "pin") { root.previewText = r.pin.text; return }
        if (r.entry.isImage) {
            root.previewText = ""
            root.previewImage = root.thumbs[r.entry.id] || ""
            return
        }
        root.previewText = r.title   // instant, replaced by the full text below
        if (!decodeProc.running) startDecode(String(r.entry.id))
    }

    Timer { id: previewDebounce; interval: 90; onTriggered: root.requestPreview() }

    // ── actions ──

    function copyRow(row, paste) {
        if (!row) return
        var helper = theme.scriptDir + "/clip-paste.sh"
        if (row.kind === "pin") {
            // literal text goes to the helper's stdin
            Quickshell.execDetached({ command: ["bash", "-c", 'printf %s "$1" | bash "$2" "$3"', "_",
                                                row.pin.text, helper, paste ? "text" : "copytext"] })
        } else {
            if (!/^[0-9]+$/.test(String(row.entry.id))) return
            Quickshell.execDetached({ command: ["bash", helper, paste ? "id" : "copy", String(row.entry.id)] })
        }
        close()
    }

    // Deleting: the row disappears at once; cliphist deletes run one at a time.
    property var _deleteQueue: []

    function removeRow(row) {
        var at = picker.selectedIndex
        if (row.kind === "pin") {
            savePins(root.pins.filter(function (p) { return p.key !== row.pin.key }))
            rebuildKeeping(at)
            return
        }
        var id = String(row.entry.id)
        root.allEntries = root.allEntries.filter(function (e) { return e.id !== id })
        rebuildKeeping(at)
        _deleteQueue = _deleteQueue.concat([id])
        _runDelete()
    }

    function _runDelete() {
        if (deleteProc.running || _deleteQueue.length === 0) return
        var id = _deleteQueue[0]
        _deleteQueue = _deleteQueue.slice(1)
        deleteProc.command = ["bash", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "_", id]
        deleteProc.running = true
    }

    Process {
        id: deleteProc
        onExited: {
            if (root._deleteQueue.length > 0) root._runDelete()
            else root.load()          // reconcile with cliphist once the queue is empty
        }
    }

    function wipeAll() {
        if (!root.confirmWipe) {
            root.confirmWipe = true
            wipeTimer.restart()
            return
        }
        root.confirmWipe = false
        wipeProc.running = true
    }

    Process {
        id: wipeProc
        command: ["cliphist", "wipe"]
        onExited: root.load()
    }

    Timer { id: wipeTimer; interval: 3000; onTriggered: root.confirmWipe = false }

    // Pin a text entry (decoded in full so long snippets survive history pruning).
    function pinRowText(row) {
        if (row.kind === "pin") {
            savePins(root.pins.filter(function (p) { return p.key !== row.pin.key }))
            rebuildKeeping(picker.selectedIndex)
            say("Unpinned")
            return
        }
        if (row.entry.isImage) { say("Only text can be pinned"); return }
        pinProc.command = ["cliphist", "decode", String(row.entry.id)]
        pinProc.running = true
    }

    Process {
        id: pinProc
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text
                if (!text.trim()) return
                var list = root.pins.filter(function (p) { return p.text !== text })
                list.unshift({ key: "p" + Date.now(), text: text })
                root.savePins(list.slice(0, 30))
                root.say("Pinned")
                root.rebuild()
            }
        }
    }

    function say(text) {
        root.notice = text
        noticeTimer.restart()
    }

    Timer { id: noticeTimer; interval: 2200; onTriggered: root.notice = "" }

    onActiveChanged: {
        if (!active) { confirmWipe = false; return }
        picker.reset()
        picker.query = ""
        loadPins()
        load()
        rebuild()
        Qt.callLater(function () { picker.focusSearch() })
    }

    PickerPanel {
        id: picker
        anchors.fill: parent
        theme: root.theme
        active: root.active
        placeholder: "Search clipboard history…"
        rowHeight: 46
        iconSize: 30
        listWidth: 560
        previewWidth: 300
        hints: root.confirmWipe ? "Press Ctrl+Shift+D again to clear ALL history (pins are kept)"
             : root.notice !== "" ? root.notice
             : "↵ copy · ⇧↵ paste · ^S pin · ^D delete · ^⇧D clear · esc"

        onQueryChanged: root.rebuild()
        onSelectedIndexChanged: previewDebounce.restart()
        onRowsChanged: previewDebounce.restart()
        onActivated: (row, alt) => root.copyRow(row, alt)
        onDeleteRequested: (row, all) => { if (all || !row) root.wipeAll(); else root.removeRow(row) }
        onMarkRequested: row => root.pinRowText(row)
        onCloseRequested: root.close()

        preview: Component {
            Item {
                id: pv
                property var row: null

                // text
                Flickable {
                    anchors.fill: parent
                    visible: root.previewImage === ""
                    contentHeight: previewLabel.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Text {
                        id: previewLabel
                        width: parent.width
                        text: root.previewText
                        color: root.theme.text
                        font.pixelSize: root.theme.fontSizeMin + 1
                        font.family: root.theme.fontUi
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        textFormat: Text.PlainText
                    }
                }

                // image
                Image {
                    anchors.fill: parent
                    visible: root.previewImage !== ""
                    source: root.previewImage ? "file://" + root.previewImage : ""
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 600
                    sourceSize.height: 600
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }
            }
        }
    }
}
