import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property bool active: false
    property var dataSource: null  // shared KDEConnectData instance
    signal close()

    property var devices: dataSource ? dataSource.devices : []

    clip: true
    implicitWidth: 340
    implicitHeight: 400

    Rectangle {
        anchors.fill: parent
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 16
        bottomRightRadius: 16
        color: theme.color
        border.color: theme.surface0
        border.width: 2

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: theme.color
        }
    }

    Flickable {
        id: scrollView
        anchors.fill: parent
        anchors.margins: 14
        contentHeight: contentColumn.implicitHeight
        clip: true

        ColumnLayout {
            id: contentColumn
            width: scrollView.width
            spacing: 10

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "KDE Connect"
                    color: theme.text
                    font.pixelSize: theme.fontSize + 1
                    font.bold: true
                    font.family: theme.font
                    Layout.fillWidth: true
                }

                Text {
                    text: "×"
                    color: theme.subtext0
                    font.pixelSize: theme.fontSize + 4
                    font.family: theme.font

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.surface0
            }

            // No devices state
            Text {
                Layout.fillWidth: true
                visible: root.devices.length === 0
                text: "No devices connected"
                color: theme.subtext0
                font.pixelSize: theme.fontSize
                font.family: theme.font
                horizontalAlignment: Text.AlignHCenter
            }

            // Device cards
            Repeater {
                model: root.devices

                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8

                    // Device card
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 70
                        radius: 10
                        color: theme.surface0

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Text {
                                text: ""
                                color: "#ffffff"
                                font.pixelSize: theme.fontSize + 12
                                font.family: theme.font
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: modelData ? modelData.name || "Unknown" : "Unknown"
                                        color: theme.text
                                        font.pixelSize: theme.fontSize
                                        font.weight: Font.Medium
                                        font.family: theme.font
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData && modelData.battery !== null && modelData.battery >= 0
                                              ? modelData.battery + "%" : ""
                                        color: {
                                            if (!modelData || modelData.battery === null) return "#ffffff"
                                            var b = modelData.battery
                                            if (b < 20) return "#f38ba8"
                                            if (b < 50) return "#f9e2af"
                                            return "#a6e3a1"
                                        }
                                        font.pixelSize: theme.fontSize
                                        font.weight: Font.Bold
                                        font.family: theme.font
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 6
                                    radius: 3
                                    color: Qt.darker(theme.surface0, 1.2)
                                    visible: modelData && modelData.battery !== null && modelData.battery >= 0

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        radius: 3
                                        color: {
                                            if (!modelData || modelData.battery === null) return "#ffffff"
                                            var b = modelData.battery
                                            if (b < 20) return "#f38ba8"
                                            if (b < 50) return "#f9e2af"
                                            return "#a6e3a1"
                                        }
                                        width: parent.width * Math.min(1, Math.max(0,
                                            (modelData ? modelData.battery : 0) / 100))
                                    }
                                }



                                Text {
                                    text: {
                                        if (!modelData) return "Disconnected"
                                        var parts = []
                                        if (modelData.reachable) parts.push("Connected")
                                        else parts.push("Not reachable")
                                        if (modelData.charging) parts.push("Charging")
                                        if (modelData.networkType) parts.push(modelData.networkType)
                                        if (modelData.signal !== null && modelData.signal >= 0) {
                                            parts.push((modelData.signal * 25) + "%")
                                        }
                                        return parts.join(" · ")
                                    }
                                    color: theme.subtext0
                                    font.pixelSize: theme.fontSize - 2
                                    font.family: theme.font
                                }
                            }

                            // Action buttons
                            ColumnLayout {
                                spacing: 4
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    radius: 8
                                    color: theme.surface1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰀘"
                                        color: theme.text
                                        font.pixelSize: theme.fontSize + 2
                                        font.family: theme.font
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData && modelData.id)
                                                findProc.find(modelData.id)
                                        }
                                    }
                                }

                                Rectangle {
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    radius: 8
                                    color: theme.surface1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰁟"
                                        color: theme.text
                                        font.pixelSize: theme.fontSize + 2
                                        font.family: theme.font
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData && modelData.id)
                                                shareProc.share(modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Notifications section
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: theme.surface0
                        visible: modelData && modelData.notifCount > 0
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: modelData && modelData.notifCount > 0
                        spacing: 8

                        Text {
                            text: "Notifications"
                            color: theme.text
                            font.pixelSize: theme.fontSize
                            font.weight: Font.Medium
                            font.family: theme.font
                            Layout.fillWidth: true
                        }

                        Text {
                            text: modelData ? modelData.notifCount + "" : ""
                            color: theme.subtext0
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Repeater {
                        model: modelData && modelData.notifications ? modelData.notifications : []

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: topRow.implicitHeight + 16
                                + (replyArea.visible ? replyArea.implicitHeight + 8 : 0)
                            radius: 8
                            color: theme.mantle

                            property bool replying: false
                            property string replyText: ""

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                RowLayout {
                                    id: topRow
                                    Layout.fillWidth: true
                                    spacing: 8

                                    // App icon placeholder
                                    Rectangle {
                                        implicitWidth: 28
                                        implicitHeight: 28
                                        radius: 6
                                        color: theme.surface1

                                        Text {
                                            anchors.centerIn: parent
                                            text: ""
                                            color: "#ffffff"
                                            font.pixelSize: theme.fontSize + 2
                                            font.family: theme.font
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: modelData ? modelData.appName || "App" : "App"
                                            color: theme.subtext1
                                            font.pixelSize: theme.fontSize - 2
                                            font.family: theme.font
                                        }

                                        Text {
                                            text: modelData ? modelData.body || "" : ""
                                            color: theme.text
                                            font.pixelSize: theme.fontSize - 1
                                            font.family: theme.font
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // Reply button
                                    Rectangle {
                                        implicitWidth: replyBtnText.implicitWidth + 12
                                        implicitHeight: 22
                                        radius: 6
                                        color: theme.surface1
                                        visible: modelData && modelData.replyId

                                        Text {
                                            id: replyBtnText
                                            anchors.centerIn: parent
                                            text: "↩ Reply"
                                            color: theme.blue
                                            font.pixelSize: theme.fontSize - 2
                                            font.family: theme.font
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                parent.parent.parent.parent.replying =
                                                    !parent.parent.parent.parent.replying
                                            }
                                        }
                                    }

                                    // Dismiss button
                                    Rectangle {
                                        implicitWidth: 20
                                        implicitHeight: 20
                                        radius: 6
                                        color: "transparent"
                                        visible: modelData && modelData.dismissable

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            color: theme.subtext0
                                            font.pixelSize: theme.fontSize
                                            font.family: theme.font
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var devId = modelData.deviceId || ""
                                                var notifId = modelData.id || ""
                                                if (devId && notifId)
                                                    dismissProc.dismiss(devId, notifId)
                                            }
                                        }
                                    }
                                }

                                // Reply input row
                                RowLayout {
                                    id: replyArea
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 36
                                    spacing: 6
                                    visible: parent.parent.replying

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 28
                                        radius: 6
                                        color: theme.surface1

                                        TextInput {
                                            id: replyInput
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            color: theme.text
                                            font.pixelSize: theme.fontSize - 1
                                            font.family: theme.font
                                            clip: true
                                            verticalAlignment: TextInput.AlignVCenter

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "Type a reply..."
                                                color: theme.subtext0
                                                font.pixelSize: theme.fontSize - 1
                                                font.family: theme.font
                                                visible: !parent.text.length
                                            }

                                            Keys.onReturnPressed: {
                                                if (parent.text.length > 0)
                                                    sendReply()
                                            }
                                        }
                                    }

                                    Rectangle {
                                        implicitWidth: sendText.implicitWidth + 14
                                        implicitHeight: 28
                                        radius: 6
                                        color: theme.blue

                                        Text {
                                            id: sendText
                                            anchors.centerIn: parent
                                            text: "Send"
                                            color: theme.white
                                            font.pixelSize: theme.fontSize - 1
                                            font.bold: true
                                            font.family: theme.font
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (replyInput.text.length > 0)
                                                    sendReply()
                                            }
                                        }
                                    }
                                }
                            }

                            function sendReply() {
                                var devId = modelData.deviceId || ""
                                var nid = modelData.id || ""
                                var msg = replyInput.text
                                if (devId && nid && msg) {
                                    replyProc.sendReply(devId, nid, msg)
                                    replying = false
                                    replyInput.text = ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Process: find phone
    Process {
        id: findProc
        command: []

        function find(devId) {
            command = ["kdeconnect-cli", "-d", devId, "--ring"]
            running = true
        }
    }

    // Process: send file
    Process {
        id: shareProc
        command: []

        function share(devId) {
            command = ["kdeconnect-cli", "-d", devId, "--share"]
            running = true
        }
    }

    // Process: dismiss notification
    Process {
        id: dismissProc
        property string deviceId: ""
        property string notifId: ""
        command: []

        function dismiss(devId, nid) {
            deviceId = devId
            notifId = nid
            command = ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/kdeconnect.sh",
                "dismiss", devId, nid]
            running = true
        }
    }

    // Process: send reply
    Process {
        id: replyProc
        property string deviceId: ""
        property string notifId: ""
        property string message: ""
        command: []

        function sendReply(devId, nid, msg) {
            deviceId = devId
            notifId = nid
            message = msg
            command = ["dbus-send", "--print-reply", "--dest=org.kde.kdeconnect",
                "/modules/kdeconnect/devices/" + devId + "/notifications/" + nid,
                "org.kde.kdeconnect.device.notifications.notification.sendReply",
                "string:" + msg]
            running = true
        }
    }

    // Fetch devices (fallback when no shared dataSource)
    Process {
        id: fetchProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/kdeconnect.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.dataSource) return
                try {
                    var data = JSON.parse(this.text.trim())
                    root.devices = data.devices || []
                } catch (e) {
                    console.log("KDEConnect panel parse error:", e)
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: root.active && !root.dataSource && !fetchProc.running
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchProc.running = true
    }
}
