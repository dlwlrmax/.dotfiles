import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common

Rectangle {
    id: root
    property Theme theme: Theme {}
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

    color: theme.color
    radius: 12
    border.color: theme.surface0
    border.width: 1
    clip: true
    width: 400
    height: cardLayout.implicitHeight + 20

    function unescapeHtml(text) {
        if (!text) return ""
        return text.replace(/&amp;/g, '&').replace(/&lt;/g, '<')
                   .replace(/&gt;/g, '>').replace(/&quot;/g, '"')
                   .replace(/&#39;/g, "'").replace(/&#x27;/g, "'")
                   .replace(/&#x2F;/g, '/')
    }

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
        _dismissing = false
        progressValue = 1.0
        dismissTimer.stop()
        progressAnim.stop()
        if (autoDismiss && dismissTimeoutMs > 0) {
            dismissTimer.interval = dismissTimeoutMs
            dismissTimer.start()
            progressAnim.restart()
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

            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: theme.surface1

                AppIcon {
                    id: notifIcon
                    anchors.centerIn: parent
                    appId: root.latest && root.latest.desktopEntry || ""
                    iconName: root.latest && root.latest.appIcon || ""
                    size: 24
                    hideOnMissing: true
                }
                Text {
                    anchors.centerIn: parent
                    text: "\uF0E0"
                    color: theme.subtext0
                    font.pixelSize: 16
                    visible: !notifIcon.iconFound
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: root.groupData.appName || "Unknown"
                    color: theme.text
                    font.pixelSize: theme.fontSize
                    font.bold: true
                    font.family: theme.font
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: root.latest ? root.unescapeHtml(root.latest.summary || root.latest.body || "") : ""
                    color: theme.subtext0
                    font.pixelSize: theme.fontSize - 2
                    font.family: theme.font
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                visible: (root.groupData.count || 0) > 1
                implicitWidth: countText.implicitWidth + 12
                implicitHeight: 22
                radius: 11
                color: theme.surface1
                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: root.groupData.count || 0
                    color: theme.blue
                    font.pixelSize: theme.fontSize - 2
                    font.bold: true
                }
            }

            Text {
                text: root.formatTime(root.notifTimes[root.latest && root.latest.id])
                color: theme.white
                font.pixelSize: theme.fontSize - 3
                font.family: theme.font
            }
            Text {
                text: "\u00D7"
                color: theme.subtext0
                font.pixelSize: theme.fontSize + 2
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: root.requestDismiss()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.latest && root.latest.body && root.latest.summary
            text: root.latest ? root.unescapeHtml(root.latest.body || "") : ""
            color: theme.text
            font.pixelSize: theme.fontSize - 2
            font.family: theme.font
            maximumLineCount: 2
            elide: Text.ElideRight
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }

        ColumnLayout {
            visible: root.expanded
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
                        text: root.unescapeHtml(modelData.summary || modelData.body || "")
                        color: theme.subtext0
                        font.pixelSize: theme.fontSize - 3
                        font.family: theme.font
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    Text {
                        id: closeText
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u00D7"
                        color: theme.subtext0
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
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
            color: Qt.rgba(0, 0, 0, 0.2)
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
        onClicked: root.expanded = !root.expanded
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        z: 999
        onContainsMouseChanged: {
            if (root._dismissed || root._dismissing || !root.autoDismiss) return
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
