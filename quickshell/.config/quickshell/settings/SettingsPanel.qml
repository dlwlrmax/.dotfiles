import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.controls

// Shell preferences and health. Everything here is persisted by Prefs (or the
// weather provider for units) and applies immediately.
Item {
    id: root
    property Theme theme: ThemeStore
    property bool active: false
    property var health: null          // DataProviders.healthData
    property var weather: null         // DataProviders.weatherData
    property var volumeData: null      // DataProviders.volumeData (sound / mic tiles)
    property var notifData: null       // DataProviders.notifData (do not disturb)
    property var wallpaper: null       // DataProviders.wallpaperData (theme from wallpaper)
    signal close()

    readonly property real maxHeight: {
        var scr = root.QsWindow.window ? root.QsWindow.window.screen : null
        return Math.min(760, scr ? scr.height - theme.barHeight - 24 : 760)
    }

    clip: true
    implicitWidth: theme.panelWidthM
    implicitHeight: Math.min(maxHeight, content.implicitHeight + 2 * theme.panelMargin)

    onActiveChanged: {
        if (active) { scroll.contentY = 0; if (health) health.checkDeps() }
    }

    PanelBackground { anchors.fill: parent }

    Flickable {
        id: scroll
        anchors.fill: parent
        anchors.margins: theme.panelMargin
        contentWidth: width
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: content
            width: scroll.width
            spacing: 10

            PanelHeader {
                theme: root.theme
                title: "Settings"
                onClose: root.close()
            }

            // ── quick toggles ──
            QuickTiles {
                theme: root.theme
                active: root.active
                volumeData: root.volumeData
                notifData: root.notifData
            }

            // ── theme ──
            SectionCard {
                theme: root.theme
                title: "Theme"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Badge {
                        theme: root.theme
                        text: "Catppuccin"
                        clr: theme.highlight
                        solid: Prefs.themeMode !== "wallpaper"
                        pixelSize: theme.fontSize - 1
                        implicitHeight: 26
                        clickable: true
                        onClicked: Prefs.setThemeMode("catppuccin")
                    }

                    Badge {
                        theme: root.theme
                        text: "\uf03e  From wallpaper"
                        clr: theme.highlight
                        solid: Prefs.themeMode === "wallpaper"
                        pixelSize: theme.fontSize - 1
                        implicitHeight: 26
                        clickable: true
                        onClicked: Prefs.setThemeMode("wallpaper")
                    }

                    Item { Layout.fillWidth: true }

                    Badge {
                        theme: root.theme
                        text: "Wallpapers\u2026"
                        clr: theme.blue
                        pixelSize: theme.fontSize - 1
                        implicitHeight: 26
                        clickable: true
                        onClicked: Panels.toggle("wallpaper", Panels.screenName, 0)
                    }
                }

                // current wallpaper + follow / regenerate (wallpaper mode)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: Prefs.themeMode === "wallpaper"

                    Rectangle {
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: 54
                        radius: theme.radiusMd
                        color: theme.surface0
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: root.wallpaper && root.wallpaper.current ? "file://" + root.wallpaper.current : ""
                            sourceSize.width: 192
                            sourceSize.height: 108
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: root.wallpaper ? root.wallpaper.nameOf(root.wallpaper.current || "") : ""
                            color: theme.text
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.fontUi
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            spacing: 6

                            Badge {
                                theme: root.theme
                                text: Prefs.autoFollow ? "\uf00c  Follows wallpaper" : "Follow wallpaper"
                                clr: Prefs.autoFollow ? theme.green : theme.subtext0
                                clickable: true
                                onClicked: Prefs.setAutoFollow(!Prefs.autoFollow)
                            }

                            Badge {
                                theme: root.theme
                                text: (root.wallpaper && root.wallpaper.generating ? "working\u2026" : Glyphs.refresh + " Regenerate")
                                clr: theme.blue
                                clickable: !!root.wallpaper && !root.wallpaper.generating
                                onClicked: root.wallpaper.regenerate()
                            }
                        }
                    }
                }

                // the whole palette
                Flow {
                    Layout.fillWidth: true
                    spacing: 3

                    Repeater {
                        model: ["crust", "mantle", "base", "surface0", "surface1", "surface2", "overlay0", "overlay1", "overlay2",
                                "subtext0", "subtext1", "text", "rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach",
                                "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender"]

                        Rectangle {
                            required property string modelData
                            width: 22
                            height: 22
                            radius: 5
                            color: root.theme[modelData]
                            border.width: 1
                            border.color: Qt.alpha(root.theme.text, 0.2)
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: Prefs.themeMode === "wallpaper"
                          ? "Colours are generated from the wallpaper and update live."
                          : "The built-in Catppuccin Mocha palette."
                    color: theme.overlay0
                    font.pixelSize: theme.fontSizeMin
                    font.family: theme.fontUi
                    wrapMode: Text.WordWrap
                }
            }

            // ── health ──
            SectionCard {
                theme: root.theme
                title: "Status"

                Badge {
                    visible: !root.health || root.health.count === 0
                    theme: root.theme
                    text: "  Everything looks fine"
                    clr: theme.green
                }

                Repeater {
                    model: root.health ? root.health.issues : []

                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: 4
                            color: modelData.level === "error" ? theme.red : theme.yellow
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: modelData.title
                                color: theme.text
                                font.pixelSize: theme.fontSize - 1
                                font.bold: true
                                font.family: theme.fontUi
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.detail
                                color: theme.subtext0
                                font.pixelSize: theme.fontSizeMin
                                font.family: theme.fontUi
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: !!root.health
                    spacing: 6

                    Badge {
                        theme: root.theme
                        text: Glyphs.refresh + " Re-check"
                        clr: theme.blue
                        clickable: true
                        onClicked: {
                            root.health.checkDeps()
                            if (root.weather) root.weather.refresh()
                        }
                    }

                    Text {
                        visible: !!root.health && root.health.missingDeps.length > 0
                        text: "Install missing packages: scripts/check-deps.sh"
                        color: theme.overlay0
                        font.pixelSize: theme.fontSizeMin
                        font.family: theme.fontUi
                    }
                }
            }

            // ── appearance ──
            SectionCard {
                theme: root.theme
                title: "Accent colour"

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: Prefs.themeMode === "wallpaper" ? Prefs.accentChoices
                               : Prefs.accentChoices.filter(function (a) { return a !== "auto" })

                        Rectangle {
                            id: sw
                            required property string modelData
                            readonly property bool picked: Prefs.accentName === modelData
                            width: 28
                            height: 28
                            radius: 14
                            color: modelData === "auto" ? ShellPalette.get("highlight", root.theme.mauve) : root.theme[modelData]
                            border.width: picked ? 3 : 1
                            border.color: picked ? root.theme.text : Qt.alpha(root.theme.text, 0.25)
                            scale: swMa.containsMouse ? 1.1 : 1
                            Behavior on scale { SpringAnimation { spring: root.theme.springPress; damping: root.theme.dampingPress; epsilon: root.theme.epsilonPress } }

                            Text {
                                anchors.centerIn: parent
                                visible: sw.picked || sw.modelData === "auto"
                                text: sw.modelData === "auto" && !sw.picked ? "A" : Glyphs.check
                                color: root.theme.base
                                font.pixelSize: root.theme.fontSize
                                font.bold: true
                                font.family: root.theme.font
                            }

                            MouseArea {
                                id: swMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Prefs.setAccent(sw.modelData)
                            }
                        }
                    }
                }

                Text {
                    text: "Used for today's date, the play button and focused search fields."
                    color: theme.overlay0
                    font.pixelSize: theme.fontSizeMin
                    font.family: theme.fontUi
                }
            }

            // ── bar ──
            SectionCard {
                theme: root.theme
                title: "Bar"

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: Prefs.barItems

                        Badge {
                            required property var modelData
                            readonly property bool on: Prefs.show(modelData.key)
                            theme: root.theme
                            text: (on ? "  " : "") + modelData.label
                            clr: on ? theme.highlight : theme.subtext0
                            pixelSize: theme.fontSize - 1
                            implicitHeight: 24
                            clickable: true
                            onClicked: Prefs.setShown(modelData.key, !on)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Stats on every screen"
                        color: theme.subtext1
                        font.pixelSize: theme.fontSize - 1
                        font.family: theme.fontUi
                        Layout.fillWidth: true
                    }

                    Badge {
                        theme: root.theme
                        text: Prefs.statsAllScreens ? "On" : "Primary only"
                        clr: Prefs.statsAllScreens ? theme.green : theme.subtext0
                        solid: Prefs.statsAllScreens
                        clickable: true
                        onClicked: Prefs.setStatsAllScreens(!Prefs.statsAllScreens)
                    }
                }
            }

            // ── units ──
            SectionCard {
                visible: !!root.weather
                theme: root.theme
                title: "Weather units"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Badge { theme: root.theme; text: "°C"; clr: theme.blue; solid: !root.weather.fahrenheit; clickable: true; onClicked: root.weather.fahrenheit = false }
                    Badge { theme: root.theme; text: "°F"; clr: theme.blue; solid: root.weather.fahrenheit; clickable: true; onClicked: root.weather.fahrenheit = true }
                    Item { Layout.preferredWidth: 8 }
                    Badge { theme: root.theme; text: "km/h"; clr: theme.blue; solid: !root.weather.mph; clickable: true; onClicked: root.weather.mph = false }
                    Badge { theme: root.theme; text: "mph"; clr: theme.blue; solid: root.weather.mph; clickable: true; onClicked: root.weather.mph = true }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "Location: weather panel"
                        color: theme.overlay0
                        font.pixelSize: theme.fontSizeMin
                        font.family: theme.fontUi
                    }
                }
            }
        }
    }
}
