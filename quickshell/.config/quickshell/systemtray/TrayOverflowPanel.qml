import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.common

Item {
    id: root
    property Theme theme: ThemeStore
    property bool active: false
    signal close()

    clip: true
    Component.onCompleted: ShellState.loadTrayPins()
    implicitWidth: theme.panelWidthS
    implicitHeight: contentCol.implicitHeight + 28

    PanelBackground {
        anchors.fill: parent
    }

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        PanelHeader {
            theme: root.theme
            title: "System tray"
            onClose: root.close()
        }

        Text {
            Layout.fillWidth: true
            visible: SystemTray.items.values.length > 0
            text: "Pinned icons stay in the bar. Click an icon to open it."
            color: theme.overlay0
            font.pixelSize: theme.fontSizeMin
            font.family: theme.fontUi
            wrapMode: Text.WordWrap
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: SystemTray.items

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool pinned: ShellState.trayPins === null
                        ? index < ShellState.trayDefaultVisible : ShellState.trayPins.indexOf(modelData.id) >= 0
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: theme.radiusMd
                    color: rowMa.containsMouse ? Qt.alpha(theme.surface0, 0.8) : Qt.alpha(theme.surface0, 0.35)

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { row.modelData.activate(); root.close() }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10

                        TrayIcon {
                            modelData: row.modelData
                            index: row.index
                            boxSize: 26
                            onActivated: root.close()
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.tooltipTitle || row.modelData.title || row.modelData.id
                                color: theme.text
                                font.pixelSize: theme.fontSize - 1
                                font.family: theme.fontUi
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text !== "" && text !== parent.children[0].text
                                text: row.modelData.id
                                color: theme.overlay0
                                font.pixelSize: theme.fontSizeMin
                                font.family: theme.fontUi
                                elide: Text.ElideRight
                            }
                        }

                        Badge {
                            theme: root.theme
                            text: row.pinned ? "Pinned" : "Pin"
                            clr: row.pinned ? theme.green : theme.subtext0
                            solid: row.pinned
                            clickable: true
                            onClicked: ShellState.setTrayPinned(row.modelData.id, !row.pinned,
                                SystemTray.items.values.map(function (x) { return x.id }))
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: SystemTray.items.values.length === 0
            text: "No tray icons"
            color: theme.subtext0
            font.pixelSize: theme.fontSize
            font.family: theme.font
        }
    }
}
