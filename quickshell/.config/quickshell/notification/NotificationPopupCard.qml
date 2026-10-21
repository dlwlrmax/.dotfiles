import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common

Rectangle {
    id: root
    property Theme theme: ThemeStore
    property var groupData: ({})
    property var notifTimes: ({})
    property bool expanded: false
    property bool autoDismiss: !latest || latest.urgency !== 2
    property int dismissTimeoutMs: {
        if (latest && latest.expireTimeout > 0) return latest.expireTimeout
        return latest && latest.urgency === 0 ? 8000 : 10000
    }
    property bool _dismissing: false
    property bool _dismissed: false
    property bool _hoverPaused: false
    property real progressValue: 1.0
    property real _hoverElapsedBeforePause: 0
    readonly property var latest: groupData && groupData.latest ? groupData.latest : null

    signal dismissed()
    signal dismissRequested()
    signal messageDismissRequested(var notifId)
    // function(notifId, text) -> bool; set by the popup. false = notification is gone.
    property var replyHandler: null
    property bool _replyFailed: false

    color: theme.panelColor
    radius: theme.radiusXl
    border.color: theme.surface0
    border.width: 1
    clip: true
    width: 400
    // implicitHeight, not height: the popup's ColumnLayout (and the window sized from it)
    // only follows implicit sizes. With a plain height, a card that grows (newer, longer
    // message in the group, expanded list, reply box) got cut off at its first size.
    implicitHeight: cardLayout.implicitHeight + 20

    function formatTime(unixEpoch) {
        if (!unixEpoch) return ""
        var d = new Date(unixEpoch * 1000)
        var pad = function(n) { return n < 10 ? "0" + n : n }
        return pad(d.getHours()) + ":" + pad(d.getMinutes())
    }

    function stopTimers() {
        dismissTimer.stop()
        hoverSafety.stop()
        progressAnim.stop()
    }

    function resetTimer() {
        if (_dismissed) return
        if (replyField.activeFocus) return   // typing: stay up; focus loss restarts it
        _dismissing = false
        progressValue = 1.0
        dismissTimer.stop()
        progressAnim.stop()
        if (autoDismiss && dismissTimeoutMs > 0) {
            dismissTimer.interval = dismissTimeoutMs
            progressAnim.restart()
            // Cursor on the card (new message arrived mid-hover): hold the fresh
            // countdown paused; leaving the card resumes it from full.
            if (hoverArea.containsMouse) {
                _hoverElapsedBeforePause = 0
                _hoverPaused = true
                hoverSafety.restart()
            } else {
                dismissTimer.start()
            }
        }
    }

    function fadeOut() {
        if (_dismissed) return
        stopTimers()
        fadeAnim.to = 0
        fadeAnim.start()
    }

    function requestDismiss() {
        if (_dismissing || _dismissed) return
        _dismissing = true
        stopTimers()
        dismissRequested()
        fadeOut()
    }

    onGroupDataChanged: resetTimer()

    Timer {
        id: dismissTimer
        interval: root.dismissTimeoutMs
        repeat: false
        onTriggered: {
            if (root._dismissing || root._dismissed) return
            root._dismissing = true
            root.dismissRequested()
            root.fadeOut()
        }
    }

    NumberAnimation on progressValue {
        id: progressAnim
        from: 1.0
        to: 0.0
        duration: root.dismissTimeoutMs
        running: root.autoDismiss && root.dismissTimeoutMs > 0 && !root._dismissing
        paused: root._hoverPaused
    }

    Timer {
        id: hoverSafety
        interval: 30000
        onTriggered: {
            if (root._dismissed || root._dismissing) return
            if (!dismissTimer.running && root.autoDismiss
                    && !hoverArea.containsMouse) {
                root._hoverPaused = false
                dismissTimer.interval = Math.max(100, root.dismissTimeoutMs * root.progressValue)
                dismissTimer.start()
            }
        }
    }

    Component.onCompleted: resetTimer()

    NumberAnimation {
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 150
        running: true
    }

    transform: Translate { id: slideTransform; y: -8 }
    NumberAnimation {
        target: slideTransform
        property: "y"
        from: -8
        to: 0
        duration: 180
        easing.type: Easing.OutCubic
        running: true
    }

    PropertyAnimation {
        id: fadeAnim
        target: root
        property: "opacity"
        duration: 200
        // Never destroy the Repeater delegate directly: that leaves a dangling
        // model row and Qt warns "indestructible object". Emit dismissed();
        // NotificationPopup removes the model row, which destroys the delegate.
        onFinished: {
            if (root._dismissed) return
            root._dismissed = true
            root.stopTimers()
            root.dismissed()
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 8
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        width: 4
        radius: 2
        color: root.latest && root.latest.urgency === 2 ? theme.red : theme.surface1
    }

    ColumnLayout {
        id: cardLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        anchors.leftMargin: 26
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            NotifIcon {
                theme: root.theme
                notif: root.latest
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: root.groupData.appName || "Unknown"
                    color: theme.text
                    font.pixelSize: theme.fontSize
                    font.bold: true
                    font.family: theme.fontUi
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    // Full title; with no title the body below shows everything.
                    text: root.latest && root.latest.summary ? Sanitize.formatBody(root.latest.summary) : ""
                    visible: text !== ""
                    color: theme.subtext0
                    font.pixelSize: theme.fontSizeMin
                    font.family: theme.fontUi
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    Layout.fillWidth: true
                    textFormat: Text.StyledText
                }
            }

            Rectangle {
                visible: (root.groupData.count || 0) > 1
                implicitWidth: countText.implicitWidth + 12
                implicitHeight: 22
                radius: 11
                color: theme.surface1
                Text {
                    font.family: theme.font
                    id: countText
                    anchors.centerIn: parent
                    text: root.groupData.count || 0
                    color: theme.blue
                    font.pixelSize: theme.fontSizeMin
                    font.bold: true
                }
            }

            Text {
                text: root.formatTime(root.latest
                    ? (root.notifTimes[root.latest.id] || root.latest.timestamp) : 0)
                color: theme.onAccent
                font.pixelSize: theme.fontSizeMin
                font.family: theme.font
            }
            Text {
                font.family: theme.font
                text: Glyphs.close
                color: theme.subtext0
                font.pixelSize: theme.fontSize + 2
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestDismiss()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: !!(root.latest && root.latest.body)
            // Whole body: the card grows to fit (no line cap), so cumulative chat
            // bodies show every line including the newest.
            text: Sanitize.formatBody(root.latest ? root.latest.body : "")
            color: theme.text
            font.pixelSize: theme.fontSizeMin
            font.family: theme.fontUi
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            textFormat: Text.StyledText
        }

        // Inline reply (apps that support it, e.g. chats relayed by KDE Connect).
        // Typing pauses auto-dismiss; Enter sends, Esc gives up.
        TextField {
            id: replyField
            visible: !!(root.latest && root.latest.hasReply)
            Layout.fillWidth: true
            placeholderText: root.latest && root.latest.replyPlaceholder ? root.latest.replyPlaceholder : "Reply…"
            color: theme.text
            placeholderTextColor: theme.surface1
            font.pixelSize: theme.fontSizeMin
            font.family: theme.font
            leftPadding: 8
            rightPadding: 8
            background: Rectangle {
                radius: theme.radiusMd
                color: theme.surface0
                border.color: root._replyFailed ? theme.red : replyField.activeFocus ? theme.blue : "transparent"
                border.width: 1
            }

            onActiveFocusChanged: {
                if (root._dismissed || root._dismissing || !root.autoDismiss) return
                if (activeFocus) {
                    root.stopTimers()
                    root._hoverPaused = true
                    return
                }
                // Focus left: start a fresh countdown. If the cursor is still on the card,
                // hold it paused like a hover would; leaving the card resumes it.
                root.resetTimer()
                if (hoverArea.containsMouse) {
                    dismissTimer.stop()
                    root._hoverElapsedBeforePause = 0
                    root._hoverPaused = true
                } else {
                    root._hoverPaused = false
                }
            }
            onTextChanged: root._replyFailed = false
            onAccepted: {
                var t = text.trim()
                if (t === "" || !root.latest) return
                var ok = root.replyHandler ? root.replyHandler(root.latest.id, t) : false
                if (!ok) {
                    // Keep the draft so it can be copied elsewhere.
                    root._replyFailed = true
                    return
                }
                text = ""
                focus = false
                root.requestDismiss()
            }
            Keys.onEscapePressed: { text = ""; focus = false }
        }

        Text {
            visible: root._replyFailed
            text: "Couldn't send: the notification is gone. Reply in the app."
            color: theme.red
            font.pixelSize: theme.fontSizeMin
            font.family: theme.fontUi
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }

        ColumnLayout {
            visible: root.expanded && (root.groupData.count || 0) > 1
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: root.groupData.messages || []
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: messageText.implicitHeight + 8
                    radius: 5
                    color: theme.surface1
                    Text {
                        id: messageText
                        anchors.left: parent.left
                        anchors.right: closeText.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 6
                        // "Title: full body" (title alone is often just the group/app name)
                        text: modelData.summary && modelData.body
                            ? Sanitize.formatBody(modelData.summary) + ": " + Sanitize.formatBody(modelData.body)
                            : Sanitize.formatBody(modelData.summary || modelData.body)
                        color: theme.subtext0
                        font.pixelSize: theme.fontSizeMin
                        font.family: theme.fontUi
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        textFormat: Text.StyledText
                    }
                    Text {
                        font.family: theme.font
                        id: closeText
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: Glyphs.close
                        color: theme.subtext0
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.messageDismissRequested(modelData.id)
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 3
            radius: 1.5
            color: theme.trackOverlay
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root.progressValue
                radius: 1.5
                color: theme.blue
            }
        }
    }

    MouseArea {
        id: toggleArea
        anchors.fill: parent
        z: -1
        cursorShape: (root.groupData.count || 0) > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if ((root.groupData.count || 0) > 1) root.expanded = !root.expanded
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        z: 999
        onContainsMouseChanged: {
            if (root._dismissed || root._dismissing || !root.autoDismiss) return
            if (replyField.activeFocus) return
            root._hoverPaused = containsMouse
            if (containsMouse) {
                root._hoverElapsedBeforePause = root.dismissTimeoutMs * (1 - root.progressValue)
                dismissTimer.stop()
                hoverSafety.start()
            } else {
                var remaining = root.dismissTimeoutMs - root._hoverElapsedBeforePause
                if (remaining > 0) {
                    dismissTimer.interval = Math.max(100, remaining)
                    dismissTimer.start()
                }
                hoverSafety.stop()
            }
        }
    }
}
