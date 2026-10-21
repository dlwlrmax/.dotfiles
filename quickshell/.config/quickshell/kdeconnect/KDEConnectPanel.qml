import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.common

Item {
    id: root
    property Theme theme: ThemeStore
    property bool active: false
    property var dataSource: null  // shared KDEConnectData instance
    signal close()

    property var devices: dataSource ? dataSource.devices : []
    readonly property bool daemonUp: dataSource ? dataSource.daemonUp : true

    // Capped like the notification panel: content height up to the screen under the bar.
    readonly property real maxHeight: {
        var scr = root.QsWindow.window ? root.QsWindow.window.screen : null
        return Math.min(640, scr ? scr.height - theme.barHeight - 24 : 640)
    }

    clip: true
    implicitWidth: theme.panelWidthS
    implicitHeight: Math.min(maxHeight, content.implicitHeight + 2 * theme.panelMargin)

    PanelBackground {
        anchors.fill: parent
    }

    KdeActions {
        id: actions
        theme: root.theme
        dataSource: root.dataSource
    }

    Flickable {
        id: scrollView
        anchors.fill: parent
        anchors.margins: theme.panelMargin
        contentWidth: width
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: content
            width: scrollView.width
            spacing: 10

            PanelHeader {
                theme: root.theme
                title: "KDE Connect"
                onClose: root.close()

                Badge {
                    theme: root.theme
                    text: Glyphs.refresh + " Search"
                    clr: theme.blue
                    clickable: true
                    visible: root.daemonUp
                    onClicked: actions.refreshDevices()
                }
            }

            // Last action result (ping sent, reply failed, ...).
            Badge {
                visible: actions.status !== ""
                theme: root.theme
                text: actions.status
                clr: actions.statusOk ? theme.green : theme.red
                Layout.maximumWidth: content.width
            }

            // kdeconnectd not on the session bus.
            ColumnLayout {
                Layout.fillWidth: true
                visible: !root.daemonUp
                spacing: 8

                Text {
                    text: "KDE Connect isn't running"
                    color: theme.text
                    font.pixelSize: theme.fontSize
                    font.family: theme.fontUi
                }

                Badge {
                    theme: root.theme
                    text: "Start KDE Connect"
                    clr: theme.blue
                    solid: true
                    pixelSize: theme.fontSize - 1
                    implicitHeight: 26
                    clickable: true
                    onClicked: actions.startDaemon()
                }
            }

            // Daemon up, nothing paired or in range.
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.daemonUp && root.devices.length === 0
                spacing: 8

                Text {
                    text: "No devices found"
                    color: theme.text
                    font.pixelSize: theme.fontSize
                    font.family: theme.fontUi
                }

                Text {
                    Layout.fillWidth: true
                    text: "Open KDE Connect on the phone (same network) and press Search."
                    color: theme.subtext0
                    font.pixelSize: theme.fontSizeMin
                    font.family: theme.fontUi
                    wrapMode: Text.WordWrap
                }
            }

            Repeater {
                model: root.devices

                DeviceCard {
                    required property var modelData
                    theme: root.theme
                    device: modelData
                    actions: actions
                }
            }
        }
    }
}
