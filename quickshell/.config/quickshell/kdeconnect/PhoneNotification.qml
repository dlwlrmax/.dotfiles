import QtQuick
import QtQuick.Layouts
import qs.common

// One phone notification: title/body, arrival time, state badges, reply and dismiss.
ColumnLayout {
    id: item

    property Theme theme: ThemeStore
    property var notif: ({})
    property var actions: null          // KdeActions
    property bool expanded: false
    property bool replying: false

    Layout.fillWidth: true
    spacing: 6

    function timeText(epoch) {
        if (!epoch) return ""
        var d = new Date(epoch * 1000), now = new Date()
        var hm = Qt.formatTime(d, "hh:mm")
        return d.toDateString() === now.toDateString() ? hm : Qt.formatDate(d, "d MMM") + " " + hm
    }

    function sendReply() {
        var msg = replyInput.text.trim().slice(0, 500)
        if (!msg || !notif.deviceId || !notif.id) return
        actions.reply(notif.deviceId, notif.id, msg)
        replyInput.text = ""
        replying = false
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: !!item.notif.title || !!item.notif.time || item.notif.dismissable === false || item.notif.silent === true

                Text {
                    visible: !!item.notif.title
                    text: item.notif.title || ""
                    color: theme.text
                    font.pixelSize: theme.fontSize - 1
                    font.bold: true
                    font.family: theme.fontUi
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Item { visible: !item.notif.title; Layout.fillWidth: true }

                Badge {
                    visible: item.notif.dismissable === false
                    theme: item.theme
                    text: "Ongoing"
                    clr: theme.yellow
                }

                Badge {
                    visible: item.notif.silent === true && item.notif.dismissable !== false
                    theme: item.theme
                    text: "Silent"
                    clr: theme.subtext0
                }

                Text {
                    visible: text !== ""
                    text: item.timeText(item.notif.time)
                    color: theme.overlay0
                    font.pixelSize: theme.fontSizeMin
                    font.family: theme.font
                }
            }

            Text {
                id: bodyText
                text: item.notif.body || ""
                visible: text !== ""
                color: theme.subtext1
                font.pixelSize: theme.fontSize - 1
                font.family: theme.fontUi
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: item.expanded ? 20 : 2
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: bodyText.visible && (bodyText.truncated || item.expanded)
                text: item.expanded ? "Show less" : "Show more"
                color: theme.blue
                font.pixelSize: theme.fontSizeMin
                font.family: theme.fontUi

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: item.expanded = !item.expanded
                }
            }
        }

        Badge {
            visible: !!item.notif.replyId
            theme: item.theme
            text: Glyphs.reply + " Reply"
            clr: theme.blue
            clickable: true
            Layout.alignment: Qt.AlignTop
            onClicked: {
                item.replying = !item.replying
                if (item.replying) Qt.callLater(function () { replyInput.forceActiveFocus() })
            }
        }

        IconButton {
            visible: item.notif.dismissable === true
            theme: item.theme
            text: Glyphs.close
            glyphSize: theme.fontSize - 1
            implicitWidth: 22
            implicitHeight: 22
            Layout.alignment: Qt.AlignTop
            onClicked: item.actions.dismiss(item.notif.deviceId, item.notif.id)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: item.replying

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 28
            radius: theme.radiusMd
            color: theme.surface1
            border.width: replyInput.activeFocus ? 1 : 0
            border.color: theme.blue

            TextInput {
                id: replyInput
                anchors.fill: parent
                anchors.margins: 6
                color: theme.text
                font.pixelSize: theme.fontSize - 1
                font.family: theme.fontUi
                clip: true
                maximumLength: 500
                verticalAlignment: TextInput.AlignVCenter
                Keys.onReturnPressed: item.sendReply()
                Keys.onEnterPressed: item.sendReply()
                Keys.onEscapePressed: event => { item.replying = false; event.accepted = true }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Type a reply…"
                    color: theme.overlay0
                    font.pixelSize: theme.fontSize - 1
                    font.family: theme.fontUi
                    visible: !parent.text.length
                }
            }
        }

        Badge {
            theme: item.theme
            text: "Send"
            clr: theme.blue
            solid: true
            pixelSize: theme.fontSize - 1
            implicitHeight: 28
            clickable: true
            onClicked: item.sendReply()
        }
    }
}
