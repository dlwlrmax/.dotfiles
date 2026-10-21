import Quickshell
import Quickshell.Hyprland._Ipc
import QtQuick
import QtQuick.Layouts
import qs.common
import qs.workspaces
import qs.windowtitle
import qs.clock
import qs.mpris
import qs.cpu
import qs.netspeed
import qs.weather
import qs.volume
import qs.battery
import qs.idleinhibitor
import qs.kdeconnect
import qs.notification
import qs.systemtray
import qs.controls

Item {
    id: bar
    property Theme theme: ThemeStore
    required property var monitor
    // name: Panels name; centerX: window-space x of the clicked widget (0 = unknown)
    signal togglePanel(string name, int centerX)
    property alias weatherWidget: barWeather
    property var kdeDataSource: null
    property var notifDataSource: null
    property var cpuDataSource: null
    property var netDataSource: null
    property var weatherDataSource: null
    property var volumeDataSource: null
    property var batteryDataSource: null
    property var healthDataSource: null
    // CPU/RAM/net stats only on the primary screen; secondary bars stay quiet.
    property bool showStats: true

    // Window-space x of an item's centre (bars span the full screen width),
    // used to anchor panels under the widget that opened them.
    function centerOf(item) {
        return item.mapToItem(null, item.width / 2, 0).x
    }

    Rectangle {
        id: barRect
        anchors.fill: parent
        color: theme.barColor
        radius: theme.radiusXl

        RowLayout {
            id: leftSection
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Workspaces {
                id: workspaces
                monitor: bar.monitor
                Layout.alignment: Qt.AlignVCenter
            }

            WindowTitle {
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: Math.max(0, (bar.width / 2) - 150 - workspaces.width)
            }
        }

        Clock {
            id: centerClock
            anchors.centerIn: parent
            onTogglePanel: bar.togglePanel("calendar", bar.centerOf(centerClock))
        }

        RowLayout {
            id: rightSection
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width / 2 - centerClock.width / 2 - 32)
            spacing: 8
            clip: true
            property real mprisMaxWidth: {
                let used = 0
                let visible = 0
                for (let i = 0; i < children.length; i++) {
                    let c = children[i]
                    if (c !== mpris && c.visible) {
                        used += c.implicitWidth || 0
                        visible++
                    }
                }
                used += spacing * Math.max(0, visible - 1)
                let available = parent.width / 2 - centerClock.width / 2 - 32
                return Math.max(60, available - used - 24)
            }

            Mpris {
                id: mpris
                theme: bar.theme
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.minimumWidth: 60
                maxWidth: rightSection.mprisMaxWidth
                onTogglePanel: centerX => bar.togglePanel("mpris", centerX)
            }

            // ── system: CPU/GPU/RAM + network (primary screen only) ──
            Capsule {
                theme: bar.theme
                visible: bar.showStats

                Cpu {
                    theme: bar.theme
                    Layout.alignment: Qt.AlignVCenter
                    dataSource: bar.cpuDataSource
                    onTogglePanel: bar.togglePanel("sysUsage", bar.centerOf(this))
                }

                Separator {
                    theme: bar.theme
                    Layout.alignment: Qt.AlignVCenter
                }

                NetSpeed {
                    theme: bar.theme
                    Layout.alignment: Qt.AlignVCenter
                    dataSource: bar.netDataSource
                    onTogglePanel: bar.togglePanel("net", bar.centerOf(this))
                }
            }

            // ── status: weather, audio, phone, idle, gaming, notifications ──
            Capsule {
                theme: bar.theme
                spacing: 10

                Weather {
                    id: barWeather
                    visible: Prefs.show("weather")
                    theme: bar.theme
                    Layout.alignment: Qt.AlignVCenter
                    dataSource: bar.weatherDataSource
                    onTogglePanel: bar.togglePanel("weather", bar.centerOf(barWeather))
                }

                Volume {
                    id: volumeWidget
                    visible: Prefs.show("volume")
                    theme: bar.theme
                    Layout.alignment: Qt.AlignVCenter
                    dataSource: bar.volumeDataSource
                    onTogglePanel: bar.togglePanel("volume", bar.centerOf(volumeWidget))
                }

                KDEConnect {
                    id: kdeWidget
                    theme: bar.theme
                    dataSource: bar.kdeDataSource
                    Layout.alignment: Qt.AlignVCenter
                    onTogglePanel: centerX => bar.togglePanel("kde", centerX)
                }

                Battery {
                    id: batteryWidget
                    theme: bar.theme
                    dataSource: bar.batteryDataSource
                    onTogglePanel: centerX => bar.togglePanel("battery", centerX)
                }

                IdleInhibitorWidget {
                    visible: Prefs.show("idle")
                    theme: bar.theme
                    Layout.alignment: Qt.AlignVCenter
                }

                // Shown while the gaming profile is on, so missing popups aren't a mystery.
                Text {
                    id: gamingIndicator
                    visible: ShellState.gamingMonitor !== ""
                    text: "\uf11b"   // nf-fa-gamepad
                    color: bar.theme.peach
                    font.pixelSize: bar.theme.fontSize + 4
                    font.family: bar.theme.font
                    Layout.alignment: Qt.AlignVCenter

                    HoverHandler { id: gamingHover }

                    BarTooltip {
                        target: gamingIndicator
                        theme: bar.theme
                        hovered: gamingHover.hovered
                        ignoreQuiet: true
                        text: "Gaming mode on"
                              + (ShellState.gamingMonitor !== "*" ? " (" + ShellState.gamingMonitor + ")" : "")
                              + "\nPopups hidden on the game's screen, except critical ones"
                    }
                }

                Notification {
                    id: barNotif
                    theme: bar.theme
                    dataSource: bar.notifDataSource
                    Layout.alignment: Qt.AlignVCenter
                    onTogglePanel: bar.togglePanel("notif", bar.centerOf(barNotif))
                }

                ControlsWidget {
                    id: controlsWidget
                    visible: Prefs.show("controls")
                    issueCount: bar.healthDataSource ? bar.healthDataSource.count : 0
                    hasErrors: !!bar.healthDataSource && bar.healthDataSource.hasErrors
                    theme: bar.theme
                    onTogglePanel: bar.togglePanel("settings", bar.centerOf(controlsWidget))
                }
            }

            // ── tray ──
            Capsule {
                theme: bar.theme
                visible: Prefs.show("tray")

                SystemTray {
                    id: trayWidget
                    Layout.alignment: Qt.AlignVCenter
                    theme: bar.theme
                    onToggleOverflow: bar.togglePanel("tray", bar.centerOf(trayWidget))
                }
            }
        }
    }
}
