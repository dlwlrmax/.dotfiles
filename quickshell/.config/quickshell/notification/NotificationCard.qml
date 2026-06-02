import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Rectangle {
    id: root
    property Theme theme: Theme {}
    property var notifData: ({})
    property var onDismiss: null
    property var onAction: null

    color: theme.surface0
    radius: 12
    height: content.implicitHeight + 16
        + (actionFlow.visible ? actionFlow.implicitHeight + 6 : 0)

    property var actionList: []

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

    function updateActionList() {
        var arr = [];
        if (notifData && notifData.actions) {
            var keys = Object.keys(notifData.actions);
            for (var i = 0; i < keys.length; i++) {
                arr.push({key: keys[i], label: notifData.actions[keys[i]]});
            }
        }
        actionList = arr;
    }

    onNotifDataChanged: updateActionList()
    Component.onCompleted: updateActionList()

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        Rectangle {
            width: 36
            height: 36
            radius: 18
            color: theme.surface1
            Layout.alignment: Qt.AlignTop

            AppIcon {
                id: notifIcon
                anchors.centerIn: parent
                appId: notifData.app_icon || ""
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
                Layout.rightMargin: 24
                spacing: 6

                Text {
                    text: notifData.app_name || "Unknown"
                    color: theme.text
                    font.pixelSize: theme.fontSize
                    font.bold: true
                    font.family: theme.font
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: root.formatTime(notifData.time)
                    color: theme.white
                    font.pixelSize: theme.fontSize - 3
                    font.family: theme.font
                    Layout.alignment: Qt.AlignVCenter
                    visible: !!notifData.time
                }
            }

            Text {
                text: notifData.summary || ""
                color: theme.text
                font.pixelSize: theme.fontSize
                font.family: theme.font
                Layout.fillWidth: true
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                visible: !!notifData.summary && notifData.summary.length > 0
                textFormat: Text.StyledText
            }

            Text {
                text: notifData.body || ""
                color: theme.subtext0
                font.pixelSize: theme.fontSize - 2
                font.family: theme.font
                Layout.fillWidth: true
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                visible: !!notifData.body && notifData.body.length > 0
                textFormat: Text.StyledText
            }

            // Action buttons
            Flow {
                id: actionFlow
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 4
                visible: root.actionList.length > 0

                Repeater {
                    model: root.actionList

                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: actLabel.implicitWidth + 14
                        implicitHeight: 24
                        radius: 6
                        color: theme.surface1

                        Text {
                            id: actLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            color: theme.blue
                            font.pixelSize: theme.fontSize - 2
                            font.family: theme.font
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.onAction)
                                    root.onAction(notifData.id, modelData.key)
                            }
                        }
                    }
                }
            }
        }
    }

    Text {
        id: dismissBtn
        text: "\u00D7"
        color: theme.subtext0
        font.pixelSize: theme.fontSize + 2
        font.family: theme.font
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 4
        anchors.rightMargin: 10

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.onDismiss) root.onDismiss();
            }
        }
    }
}
