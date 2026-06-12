import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common

Rectangle {
    id: root
    property Theme theme: Theme {}
    property var notifData: ({})
    property var notifTimes: ({})
    // Critical (urgency=2) never auto-closes; user must dismiss manually.
    // expireTimeout: <0 = server default, 0 = never expire, >0 = seconds.
    property bool autoDismiss: notifData.urgency !== 2
                              && !(notifData.expireTimeout === 0)
    property int dismissTimeoutMs: {
        if (notifData.expireTimeout > 0) return notifData.expireTimeout;
        var u = notifData.urgency || 1;
        if (u === 0) return 8000;
        return 10000; // Normal or fallback
    }

    signal dismissed()

    // KDE Connect escapes HTML in body (e.g. &lt;b&gt; → literal <b>).
    // Unescape first so RichText can render actual tags.
    function unescapeHtml(text) {
        if (!text) return ""
        return text.replace(/&amp;/g, '&')
                   .replace(/&lt;/g, '<')
                   .replace(/&gt;/g, '>')
                   .replace(/&quot;/g, '"')
                   .replace(/&#39;/g, "'")
                   .replace(/&#x27;/g, "'")
                   .replace(/&#x2F;/g, '/')
    }

    clip: true
    color: theme.color
    radius: 12
    border {
        color: theme.surface1
        width: 1
    }

    property real progressValue: autoDismiss && dismissTimeoutMs > 0
        ? 1.0 - (_elapsed / dismissTimeoutMs) : 0
    property int _elapsed: 0

    width: 400
    height: content.implicitHeight + 16
        + (actionFlow.visible ? actionFlow.implicitHeight + 6 : 0)

    function getNotifTime(id) {
        var t = notifTimes[id]
        return t || 0
    }

    function actionLabel(action) {
        var t = action.text
        if (t && t.indexOf(":") > 0)
            return t.substring(t.indexOf(":") + 1)
        return t || action.identifier || ""
    }

    function formatTime(unixEpoch) {
        if (!unixEpoch) return "";
        var d = new Date(unixEpoch * 1000);
        var now = new Date();
        var pad = function(n) { return n < 10 ? "0" + n : n; };
        var hhmm = pad(d.getHours()) + ":" + pad(d.getMinutes());
        if (d.getFullYear() === now.getFullYear()
            && d.getMonth() === now.getMonth()
            && d.getDate() === now.getDate()) {
            return hhmm;
        }
        var months = ["Jan","Feb","Mar","Apr","May","Jun",
                      "Jul","Aug","Sep","Oct","Nov","Dec"];
        return months[d.getMonth()] + " " + d.getDate() + " " + hhmm;
    }

    // Countdown timer: 1s interval, pauses on hover, safety resume after 30s
    Timer {
        id: dismissTimer
        interval: 1000
        running: autoDismiss
        repeat: true
        onTriggered: {
            root._elapsed += 1000
            if (root._elapsed >= root.dismissTimeoutMs) {
                dismissTimer.stop()
                root.fadeOut()
            }
        }
    }

    // Safety: force resume timer if stuck paused > 30s (hover missed event)
    Timer {
        id: hoverSafety
        interval: 30000
        onTriggered: {
            if (!dismissTimer.running && autoDismiss)
                dismissTimer.running = true
        }
    }

    // Fade in on appear
    NumberAnimation {
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 150
        running: true
    }

    function fadeOut() {
        fadeAnim.to = 0
        fadeAnim.start()
    }

    PropertyAnimation {
        id: fadeAnim
        target: root
        property: "opacity"
        duration: 200
        onFinished: {
            root.dismissed()
            root.destroy()
        }
    }

    // --- Card content (same visual as NotificationCard) ---
    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            leftMargin: 8
            topMargin: 8
            bottomMargin: 8
        }
        width: 4
        radius: 2
        color: hoverArea.containsMouse ? theme.yellow
            : notifData.urgency === 2 ? theme.red
            : notifData.urgency === 0 ? theme.green
            : theme.blue
        visible: true
    }

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 8
        anchors.leftMargin: 24
        spacing: 10

        Rectangle {
            width: 36
            height: 36
            radius: 18
            color: theme.surface1
            Layout.alignment: Qt.AlignVCenter

            AppIcon {
                id: notifIcon
                anchors.centerIn: parent
                appId: notifData.appIcon || notifData.desktopEntry || ""
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
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: notifData.appName || "Unknown"
                    color: theme.text
                    font.pixelSize: theme.fontSize
                    font.bold: true
                    font.family: theme.font
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: root.formatTime(root.getNotifTime(notifData.id))
                    color: theme.white
                    font.pixelSize: theme.fontSize - 3
                    font.family: theme.font
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "\u00D7"
                    color: theme.subtext0
                    font.pixelSize: theme.fontSize + 2
                    font.family: theme.font
                    Layout.alignment: Qt.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.fadeOut()
                    }
                }
            }

            Text {
                text: root.unescapeHtml(notifData.summary || "")
                color: theme.text
                font.pixelSize: theme.fontSize
                font.family: theme.font
                Layout.fillWidth: true
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                visible: !!notifData.summary && notifData.summary.length > 0
                textFormat: Text.RichText
            }

            Text {
                text: root.unescapeHtml(notifData.body || "")
                color: theme.subtext0
                font.pixelSize: theme.fontSize - 2
                font.family: theme.font
                Layout.fillWidth: true
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                visible: !!notifData.body && notifData.body.length > 0
                textFormat: Text.RichText
            }

            // Action buttons
            Flow {
                id: actionFlow
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 4
                visible: notifData.actions && notifData.actions.length > 0

                Repeater {
                    model: notifData.actions ? notifData.actions.length : 0

                    delegate: Rectangle {
                        required property int index
                        implicitWidth: actLabel.implicitWidth + 14
                        implicitHeight: 24
                        radius: 6
                        color: theme.surface1

                        Text {
                            id: actLabel
                            anchors.centerIn: parent
                            text: root.actionLabel(notifData.actions[index])
                            color: theme.blue
                            font.pixelSize: theme.fontSize - 2
                            font.family: theme.font
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notifData.actions[index].invoke()
                        }
                    }
                }
            }

            // Countdown progress bar (inside content area)
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 4
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
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        z: 999
        propagateComposedEvents: true
        onContainsMouseChanged: {
            if (!autoDismiss) return
            dismissTimer.running = !containsMouse
            if (containsMouse) hoverSafety.start()
            else hoverSafety.stop()
        }
    }
}
