import QtQuick
import QtQuick.Layouts
import qs.common
import "Highlight.js" as Hl

// Notification body, one Text per line. Chat relays (KDE Connect inbox-style
// Zalo/Messenger notifications) put one message per line, so a gap between
// lines keeps consecutive messages apart while wrapped lines stay tight.
ColumnLayout {
    id: root
    property Theme theme: ThemeStore
    property string body: ""
    // Source notification object (callers pass it; not read here yet).
    property var notif: null
    property color color: theme.subtext0
    // Folded search needle (Hl.fold); matches are shown bold in highlightColor.
    property string highlight: ""
    property color highlightColor: theme.yellow
    // Total visible lines across all paragraphs; 0 = no cap.
    property int maxLines: 0
    // Paragraph whose text got cut, or that didn't fit at all. Not-yet-reported
    // paragraphs count as fitting, so "Show more" doesn't flash on first layout.
    readonly property bool truncated: {
        var s = _state
        for (var i = 0; i < paragraphs.length; i++)
            if (s[i] && s[i].cut) return true
        return false
    }

    // Independent of `highlight`: a search keystroke rebinds each delegate's
    // text instead of rebuilding every delegate.
    readonly property var paragraphs: Sanitize.formatBody(body).split("<br>")
        .filter(function(p) { return p.trim() !== "" })
    // index -> { lines, cut }: lines each paragraph actually shows.
    property var _state: ({})

    function _budget(index) {
        if (maxLines <= 0) return 1000
        var used = 0
        for (var i = 0; i < index; i++)
            used += _state[i] ? _state[i].lines : 0
        return maxLines - used
    }

    function _report(index, lines, cut) {
        var cur = _state[index]
        if (cur && cur.lines === lines && cur.cut === cut) return
        var next = Object.assign({}, _state)
        next[index] = { lines: lines, cut: cut }
        _state = next
    }

    // No reset on paragraphs change: resetting _state inside the lazily
    // evaluated chain loops; recreated delegates re-report on completion.
    spacing: 8

    Repeater {
        model: root.paragraphs
        delegate: Text {
            id: para
            required property string modelData
            required property int index
            readonly property int budget: root._budget(index)

            Layout.fillWidth: true
            visible: budget > 0
            text: Hl.mark(modelData, root.highlight, root.highlightColor)
            color: root.color
            font.pixelSize: root.theme.fontSizeMin
            font.family: root.theme.fontUi
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            maximumLineCount: Math.max(1, budget)
            elide: Text.ElideRight
            textFormat: Text.StyledText

            // budget, not visible: visible is also false while the card is hidden.
            // Deferred: writing _state mid-evaluation re-triggers budget (binding loop).
            // A Timer, not Qt.callLater: it dies with the delegate, so no call
            // lands on a destroyed card.
            function report() { reportTimer.restart() }
            Timer {
                id: reportTimer
                interval: 0
                onTriggered: root._report(para.index, para.budget > 0 ? para.lineCount : 0,
                                          para.budget <= 0 || para.truncated)
            }
            onLineCountChanged: report()
            onTruncatedChanged: report()
            onBudgetChanged: report()
            Component.onCompleted: report()
        }
    }
}
