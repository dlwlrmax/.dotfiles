import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common

Rectangle {
    id: root
    property Theme theme: Theme {}
    property var notifData: ({})
    property var notifTimes: ({})
    property bool read: false
    property bool unread: false
    property var onDismissRequest: null
    property var onMarkRead: null

    color: theme.color
    radius: 12
    border.color: theme.surface0
    border.width: 1
    opacity: root.read ? 0.55 : 1.0
    height: content.implicitHeight + 20
        + (actionFlow.visible ? actionFlow.implicitHeight + 6 : 0)

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

        Rectangle {
            width: 36
            height: 36
            radius: 18
            color: theme.surface1
            Layout.alignment: Qt.AlignVCenter

            AppIcon {
                id: notifIcon
                anchors.centerIn: parent
                appId: notifData && notifData.desktopEntry || ""
                iconName: notifData && notifData.appIcon || ""
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

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: theme.blue
                    visible: root.unread
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    id: appNameText
                    text: notifData && notifData.appName || "Unknown"
                    color: theme.text
                    font.pixelSize: theme.fontSize
                    font.bold: true
                    font.family: theme.font
                    Layout.fillWidth: true
                    elide: Text.ElideRight

                    MouseArea {
                        id: appNameHover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }

                    ToolTip.visible: appNameHover.containsMouse && appNameText.truncated
                    ToolTip.delay: 500
                    ToolTip.text: appNameText.text
                }

                Text {
                    text: root.formatTime(root.getNotifTime(notifData && notifData.id))
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
                    onClicked: {
                        if (root.onDismissRequest) root.onDismissRequest()
                        else if (notifData && notifData.dismiss) notifData.dismiss()
                    }
                    }
                }
            }

            Text {
                id: summaryText
                text: root.unescapeHtml(notifData && notifData.summary || "")
                color: theme.text
                font.pixelSize: theme.fontSize
                font.family: theme.font
                Layout.fillWidth: true
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 2
                elide: Text.ElideRight
                clip: true
                visible: !!(notifData && notifData.summary) && notifData.summary.length > 0
                textFormat: Text.RichText

                MouseArea {
                    id: summaryHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                ToolTip.visible: summaryHover.containsMouse && summaryText.truncated
                ToolTip.delay: 500
                ToolTip.text: summaryText.text
            }

            Text {
                id: bodyText
                text: root.unescapeHtml(notifData && notifData.body || "")
                color: theme.subtext0
                font.pixelSize: theme.fontSize - 2
                font.family: theme.font
                Layout.fillWidth: true
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
                clip: true
                visible: !!(notifData && notifData.body) && notifData.body.length > 0
                textFormat: Text.RichText

                MouseArea {
                    id: bodyHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                ToolTip.visible: bodyHover.containsMouse && bodyText.truncated
                ToolTip.delay: 500
                ToolTip.text: bodyText.text
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
                        radius: 6
                        color: hovered ? theme.surface0 : theme.surface1

                        property bool hovered: false

                        Text {
                            id: actLabel
                            anchors.centerIn: parent
                            text: root.actionLabel(notifData && notifData.actions ? notifData.actions[index] : null)
                            color: theme.blue
                            font.pixelSize: theme.fontSize - 2
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
