import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common

Item {
    id: root
    property Theme theme: ThemeStore
    property bool active: false
    property var dataSource: null      // DataProviders.batteryData
    signal close()

    readonly property var devices: dataSource ? dataSource.devices : []

    clip: true
    implicitWidth: theme.panelWidthS
    implicitHeight: content.implicitHeight + 2 * theme.panelMargin

    onActiveChanged: if (active && dataSource) dataSource.refresh()

    PanelBackground {
        anchors.fill: parent
    }

    ColumnLayout {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: theme.panelMargin
        spacing: 10

        PanelHeader {
            theme: root.theme
            title: "Batteries"
            onClose: root.close()
        }

        Text {
            Layout.fillWidth: true
            visible: root.devices.length === 0
            text: "No battery devices found"
            color: theme.subtext0
            font.pixelSize: theme.fontSize
            font.family: theme.fontUi
        }

        Repeater {
            model: root.devices

            delegate: Rectangle {
                id: card
                required property var modelData
                readonly property var d: modelData
                readonly property bool numeric: typeof d.capacity === "number"
                readonly property int pct: root.dataSource.level(d)
                readonly property bool charging: d.status === "Charging"
                readonly property bool low: root.dataSource.isLow(d)
                readonly property color clr: charging || d.capacity_level === "Full" ? theme.green
                                           : low ? (pct <= 10 || d.capacity_level === "Critical" ? theme.red : theme.peach)
                                           : pct < 50 ? theme.yellow : theme.green
                readonly property int minutes: root.dataSource.minutesLeft(d)
                readonly property var samples: (root.dataSource.history[d.name] || []).map(function (x) { return x.c })

                Layout.fillWidth: true
                implicitHeight: col.implicitHeight + 20
                radius: theme.radiusLg
                color: Qt.alpha(theme.surface0, 0.45)

                ColumnLayout {
                    id: col
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: card.charging ? "󰂄" : card.pct <= 10 ? "󰁺" : card.pct <= 30 ? "󰁼"
                                  : card.pct <= 60 ? "󰁾" : "󰂀"
                            color: card.clr
                            font.pixelSize: theme.fontSize + 12
                            font.family: theme.font
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: root.dataSource.label(card.d)
                                color: theme.text
                                font.pixelSize: theme.fontSize
                                font.weight: Font.Medium
                                font.family: theme.fontUi
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                spacing: 6

                                Badge {
                                    theme: root.theme
                                    text: card.d.status || "Unknown"
                                    clr: card.charging ? theme.green : card.low ? theme.peach : theme.subtext0
                                }

                                Text {
                                    visible: !!card.d.manufacturer
                                    text: card.d.manufacturer || ""
                                    color: theme.overlay0
                                    font.pixelSize: theme.fontSizeMin
                                    font.family: theme.fontUi
                                }
                            }
                        }

                        Text {
                            text: card.numeric ? card.pct + "%" : (card.d.capacity_level || "?")
                            color: card.clr
                            font.pixelSize: theme.fontSize + 3
                            font.bold: true
                            font.family: theme.font
                        }
                    }

                    // level bar (the OS reports only a coarse level for some devices)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: theme.trackColor

                        Rectangle {
                            height: parent.height
                            radius: 3
                            color: card.clr
                            width: parent.width * Math.min(1, card.pct / 100)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: card.numeric

                        Text {
                            text: card.minutes >= 0 ? "~" + root.dataSource.fmtMinutes(card.minutes) + " left"
                                  : card.charging ? "charging" : "estimating…"
                            color: theme.subtext0
                            font.pixelSize: theme.fontSizeMin
                            font.family: theme.fontUi
                            Layout.fillWidth: true
                        }

                        Sparkline {
                            values: card.samples
                            tick: root.dataSource.historyTick
                            slots: root.dataSource.maxSamples
                            clr: card.clr
                            implicitWidth: 90
                            implicitHeight: 22
                            Layout.preferredWidth: 90
                            Layout.preferredHeight: 22
                        }
                    }

                    Text {
                        visible: !card.numeric
                        Layout.fillWidth: true
                        text: "This device reports a coarse level only, so there is no percentage or estimate."
                        color: theme.overlay0
                        font.pixelSize: theme.fontSizeMin
                        font.family: theme.fontUi
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
