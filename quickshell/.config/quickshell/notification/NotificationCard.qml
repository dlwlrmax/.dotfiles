import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import "Highlight.js" as Hl

Rectangle {
    id: root
    property Theme theme: ThemeStore
    property var notifData: ({})
    property var notifTimes: ({})
    property bool read: false
    property bool unread: false
    // Long bodies show 4 lines until expanded ("Show more").
    property bool bodyExpanded: false
    // Folded search needle from the panel; matches render highlighted.
    property string highlight: ""
    property var onDismissRequest: null
    property var onMarkRead: null

    color: theme.panelColor
    radius: theme.radiusXl
    border.color: theme.surface0
    border.width: 1
    opacity: root.read ? 0.55 : 1.0
    // implicitHeight so parent layouts follow size changes (see NotificationPopupCard).
    implicitHeight: content.implicitHeight + 20   // content already includes the action buttons

    function getNotifTime(id) {
        var t = notifTimes[id]
        if (t) return t
        if (notifData && notifData.timestamp) return notifData.timestamp
        return 0
    }

    function actionLabel(action) {
        action = action || {}
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
        color: root.unread ? theme.blue
            : (notifData && notifData.urgency === 2 ? theme.red : theme.surface1)
        visible: true
    }

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 10
        anchors.leftMargin: 26
        spacing: 10

        NotifIcon {
            theme: root.theme
            notif: root.notifData
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    width: 8
                    height: 8
                    radius: theme.radiusSm
                    color: theme.blue
                    visible: root.unread
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    id: appNameText
                    text: Hl.mark(Sanitize.escapePlain(notifData && notifData.appName || "Unknown"), root.highlight, theme.yellow)
                    textFormat: Text.StyledText
                    color: theme.text
                    font.pixelSize: theme.fontSize
                    font.bold: true
                    font.family: theme.fontUi
                    Layout.fillWidth: true
                    elide: Text.ElideRight

                    MouseArea {
                        id: appNameHover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }

                    BarTooltip {
                        target: appNameText
                        theme: root.theme
                        hovered: appNameHover.containsMouse && appNameText.truncated
                        delay: 500
                        text: notifData && notifData.appName || "Unknown"
                    }
                }

                Text {
                    text: root.formatTime(root.getNotifTime(notifData && notifData.id))
                    color: theme.onAccent
                    font.pixelSize: theme.fontSizeMin
                    font.family: theme.font
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: Glyphs.close
                    color: theme.subtext0
                    font.pixelSize: theme.fontSize + 2
                    font.family: theme.font
                    Layout.alignment: Qt.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.onDismissRequest) root.onDismissRequest()
                        else if (notifData && notifData.dismiss) notifData.dismiss()
                    }
                    }
                }
            }

            Text {
                id: summaryText
                text: Hl.mark(Sanitize.escapePlain(notifData && notifData.summary || ""), root.highlight, theme.yellow)
                color: theme.text
                font.pixelSize: theme.fontSize
                font.family: theme.fontUi
                Layout.fillWidth: true
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                visible: !!(notifData && notifData.summary) && notifData.summary.length > 0
                textFormat: Text.StyledText
            }

            // Capped to 4 lines unless expanded; short bodies are unaffected.
            NotifBody {
                id: bodyText
                theme: root.theme
                body: notifData && notifData.body || ""
                notif: notifData
                highlight: root.highlight
                Layout.fillWidth: true
                maxLines: root.bodyExpanded ? 0 : 4
                visible: !!(notifData && notifData.body) && notifData.body.length > 0
            }

            Text {
                visible: bodyText.visible && (bodyText.truncated || root.bodyExpanded)
                text: root.bodyExpanded ? "Show less" : "Show more"
                color: theme.blue
                font.pixelSize: theme.fontSizeMin
                font.family: theme.fontUi

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.bodyExpanded = !root.bodyExpanded
                }
            }

            // Action buttons
            Flow {
                id: actionFlow
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 4
                visible: !!(notifData && notifData.actions) && notifData.actions.length > 0

                Repeater {
                    model: notifData && notifData.actions ? notifData.actions.length : 0

                    delegate: Rectangle {
                        required property int index
                        implicitWidth: actLabel.implicitWidth + 14
                        implicitHeight: 24
                        radius: theme.radiusMd
                        color: hovered ? theme.surface0 : theme.surface1

                        property bool hovered: false

                        Text {
                            id: actLabel
                            anchors.centerIn: parent
                            text: root.actionLabel(notifData && notifData.actions ? notifData.actions[index] : null)
                            color: theme.blue
                            font.pixelSize: theme.fontSizeMin
                            font.family: theme.font
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: parent.hovered = true
                            onExited: parent.hovered = false
                            onClicked: {
                                var action = notifData && notifData.actions ? notifData.actions[index] : null
                                if (action && action.invoke) action.invoke()
                            }
                        }
                    }
                }
            }
        }
    }

    // Click anywhere on the card body (outside the × and action buttons) to
    // mark it read. Live notifications keep .dismiss(); history rows use the
    // supplied onDismissRequest instead.
    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: root.onMarkRead ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.onMarkRead) root.onMarkRead()
        }
    }

}
