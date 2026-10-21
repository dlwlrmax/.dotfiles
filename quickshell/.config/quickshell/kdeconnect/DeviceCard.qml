import QtQuick
import QtQuick.Layouts
import qs.common

// One KDE Connect device: identity, battery, actions and grouped notifications.
Rectangle {
    id: card

    property Theme theme: ThemeStore
    property var device: ({})
    property var actions: null     // KdeActions

    // App name -> whether its group shows every message (default: just the latest).
    property var expandedGroups: ({})

    readonly property bool paired: device.paired !== false
    readonly property bool reachable: !!device.reachable
    readonly property bool hasBattery: device.battery !== null && device.battery !== undefined && device.battery >= 0
    readonly property color batteryClr: !hasBattery ? theme.text
        : device.battery < 20 ? theme.red : device.battery < 50 ? theme.yellow : theme.green
    readonly property var notifs: device.notifications || []

    function deviceGlyph(type) {
        switch (type) {
        case "tablet":  return ""
        case "laptop":  return ""
        case "desktop": return ""
        case "tv":      return ""
        default:        return ""
        }
    }

    // Newest-first notifications grouped by app, in order of first appearance.
    function grouped(list) {
        var order = [], map = {}
        for (var i = 0; i < list.length; i++) {
            var n = list[i], key = n.appName || "App"
            if (!map[key]) { map[key] = { app: key, iconPath: n.iconPath || "", items: [] }; order.push(key) }
            map[key].items.push(n)
        }
        return order.map(function (k) { return map[k] })
    }

    function hasDismissable() {
        for (var i = 0; i < notifs.length; i++) if (notifs[i].dismissable) return true
        return false
    }

    function toggleGroup(app) {
        var m = {}
        for (var k in expandedGroups) m[k] = expandedGroups[k]
        m[app] = !m[app]
        expandedGroups = m
    }

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 20
    radius: theme.radiusLg
    color: Qt.alpha(theme.surface0, 0.45)

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // ── identity + battery ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: card.deviceGlyph(card.device.type)
                color: card.reachable ? theme.text : theme.overlay0
                font.pixelSize: theme.fontSize + 10
                font.family: theme.font
                Layout.preferredWidth: 22
                horizontalAlignment: Text.AlignHCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: card.device.name || "Unknown"
                    color: theme.text
                    font.pixelSize: theme.fontSize
                    font.weight: Font.Medium
                    font.family: theme.fontUi
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 6

                    Badge {
                        theme: card.theme
                        text: !card.paired ? "not paired" : card.reachable ? "connected" : "offline"
                        clr: !card.paired ? theme.peach : card.reachable ? theme.green : theme.subtext0
                    }

                    Text {
                        visible: text !== ""
                        text: {
                            var parts = []
                            if (card.device.networkType) parts.push(card.device.networkType)
                            if (card.device.signal !== null && card.device.signal !== undefined && card.device.signal >= 0)
                                parts.push(Math.round(card.device.signal * 25) + "%")
                            return parts.join(" · ")
                        }
                        color: theme.subtext0
                        font.pixelSize: theme.fontSizeMin
                        font.family: theme.font
                    }
                }
            }

            Text {
                visible: card.hasBattery
                text: (card.device.charging ? " " : "") + card.device.battery + "%"
                color: card.batteryClr
                font.pixelSize: theme.fontSize + 1
                font.bold: true
                font.family: theme.font
            }
        }

        Rectangle {
            visible: card.hasBattery
            Layout.fillWidth: true
            implicitHeight: 5
            radius: 2
            color: theme.trackColor

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                radius: parent.radius
                color: card.batteryClr
                width: parent.width * Math.min(1, Math.max(0, (card.hasBattery ? card.device.battery : 0) / 100))
            }
        }

        // ── actions ──
        Flow {
            Layout.fillWidth: true
            spacing: 6

            Badge {
                visible: !card.paired
                theme: card.theme
                text: "Pair"
                clr: theme.blue
                solid: true
                pixelSize: theme.fontSize - 1
                implicitHeight: 24
                clickable: true
                onClicked: card.actions.pair(card.device.id)
            }

            Badge {
                visible: card.paired && !card.reachable
                theme: card.theme
                text: "Reconnect"
                clr: theme.peach
                pixelSize: theme.fontSize - 1
                implicitHeight: 24
                clickable: true
                onClicked: card.actions.refreshDevices()
            }

            Repeater {
                model: card.paired && card.reachable ? [
                    { label: " Ring", act: "ring" },
                    { label: " Ping", act: "ping" },
                    { label: " Clipboard", act: "sendClipboard" },
                    { label: " Send file", act: "shareFile" }
                ] : []

                Badge {
                    required property var modelData
                    theme: card.theme
                    text: modelData.label
                    clr: theme.subtext1
                    pixelSize: theme.fontSize - 1
                    implicitHeight: 24
                    clickable: true
                    onClicked: card.actions[modelData.act](card.device.id)
                }
            }
        }

        // ── notifications ──
        RowLayout {
            Layout.fillWidth: true
            visible: card.paired && card.notifs.length > 0
            spacing: 8

            Text {
                text: "Notifications"
                color: theme.subtext1
                font.pixelSize: theme.fontSize - 1
                font.bold: true
                font.family: theme.font
            }

            Badge {
                theme: card.theme
                text: card.notifs.length
                clr: theme.blue
            }

            Item { Layout.fillWidth: true }

            Badge {
                visible: card.hasDismissable()
                theme: card.theme
                text: "Clear"
                clr: theme.blue
                clickable: true
                onClicked: card.actions.dismissAll(card.device.id)
            }
        }

        Repeater {
            model: card.paired ? card.grouped(card.notifs) : []

            delegate: Rectangle {
                id: group
                required property var modelData
                readonly property bool multi: modelData.items.length > 1
                readonly property bool open: !!card.expandedGroups[modelData.app]

                Layout.fillWidth: true
                implicitHeight: gcol.implicitHeight + 16
                radius: theme.radiusMd
                color: theme.mantle

                // Header click toggles the group (declared first so the controls sit above it).
                MouseArea {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 40
                    enabled: group.multi
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.toggleGroup(group.modelData.app)
                }

                ColumnLayout {
                    id: gcol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        AppAvatar {
                            theme: card.theme
                            name: group.modelData.app
                            iconPath: group.modelData.iconPath
                            size: 24
                        }

                        Text {
                            text: group.modelData.app
                            color: theme.text
                            font.pixelSize: theme.fontSize - 1
                            font.bold: true
                            font.family: theme.fontUi
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Badge {
                            visible: group.multi
                            theme: card.theme
                            text: group.modelData.items.length
                            clr: theme.blue
                        }

                        Text {
                            visible: group.multi
                            text: group.open ? Glyphs.up : Glyphs.down
                            color: theme.subtext0
                            font.pixelSize: theme.fontSizeMin
                            font.family: theme.font
                        }
                    }

                    Repeater {
                        model: group.open ? group.modelData.items : group.modelData.items.slice(0, 1)

                        PhoneNotification {
                            required property var modelData
                            theme: card.theme
                            notif: modelData
                            actions: card.actions
                        }
                    }
                }
            }
        }
    }
}
