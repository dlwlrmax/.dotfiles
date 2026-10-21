import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.common
import "WeatherLogic.js" as W

Item {
    id: root
    property Theme theme: ThemeStore
    property bool active: false
    property var dataSource: null      // DataProviders.weatherData
    signal close()

    readonly property bool hasData: !!dataSource && dataSource.ok && !!dataSource.data
    readonly property var d: hasData ? dataSource.data : null
    readonly property var cur: d ? d.current : null
    readonly property bool fahrenheit: dataSource ? dataSource.fahrenheit : false
    readonly property bool mph: dataSource ? dataSource.mph : false
    readonly property string error: dataSource ? dataSource.error : ""
    readonly property string tu: W.tempUnit(fahrenheit)

    // ── location search ──
    property bool locationOpen: false
    property var searchResults: []
    property string searchStatus: ""
    property bool searching: false

    function startSearch(q) {
        q = q.trim()
        if (!q || searchProc.running) return
        searching = true
        searchStatus = ""
        searchProc.command = ["curl", "-fsS", "--max-time", "6",
            "https://geocoding-api.open-meteo.com/v1/search?count=5&language=en&format=json&name=" + encodeURIComponent(q)]
        searchProc.running = true
    }

    // "lat,lon,City,Country" — weather-common.sh skips geocoding for this form.
    function chooseLocation(r) {
        var value = r.latitude.toFixed(4) + "," + r.longitude.toFixed(4) + "," + r.name + "," + (r.country || "")
        saveProc.command = ["bash", "-c",
            "printf '%s\\n' \"$1\" > \"$HOME/.config/quickshell/weather-location\"", "_", value]
        saveProc.running = true
    }

    // Capped to the screen under the bar; the content scrolls beyond that.
    readonly property real maxHeight: {
        var scr = root.QsWindow.window ? root.QsWindow.window.screen : null
        return Math.min(880, scr ? scr.height - theme.barHeight - 24 : 880)
    }

    clip: true
    implicitWidth: theme.panelWidthM
    implicitHeight: Math.min(maxHeight, content.implicitHeight + 2 * theme.panelMargin)

    // Fresh data when the panel opens if the last fetch is older than 5 minutes.
    onActiveChanged: {
        if (active) scroll.contentY = 0
        if (active && dataSource && Date.now() / 1000 - dataSource.updatedAt > 300) dataSource.refresh()
        if (!active) locationOpen = false
    }
    // Nothing to show without a location: go straight to the search.
    onErrorChanged: if (error === "no-location" || error === "geocode") locationOpen = true

    PanelBackground {
        anchors.fill: parent
    }

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
                id: headerLayout
                theme: root.theme
                title: "Weather"
                onClose: root.close()

                Badge {
                    visible: root.dataSource && root.dataSource.updatedAt > 0
                    theme: root.theme
                    text: (root.error !== "" && root.hasData ? "stale · " : "") + (root.dataSource ? W.clock(root.dataSource.updatedAt) : "")
                    clr: root.error !== "" && root.hasData ? theme.yellow : theme.subtext0
                }

                Badge {
                    theme: root.theme
                    text: Glyphs.refresh + " Refresh"
                    clr: theme.blue
                    clickable: true
                    onClicked: if (root.dataSource) root.dataSource.refresh()
                }
            }

            // Fetch problem (kept data, if any, stays visible below).
            Badge {
                visible: root.error !== ""
                theme: root.theme
                text: root.dataSource ? root.dataSource.errorMessage || "Weather unavailable" : ""
                clr: root.error === "network" ? theme.yellow : theme.red
                Layout.maximumWidth: content.width
            }

            // ── current conditions ──
            SectionCard {
                visible: root.hasData
                theme: root.theme

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: ""
                        color: theme.subtext0
                        font.pixelSize: theme.fontSizeMin
                        font.family: theme.font
                    }

                    Text {
                        text: root.d ? root.d.location + (root.d.country ? ", " + root.d.country : "") : ""
                        color: theme.subtext1
                        font.pixelSize: theme.fontSize - 1
                        font.family: theme.fontUi
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Text {
                        text: root.cur ? root.cur.icon : ""
                        color: root.cur ? theme[W.kindKey(root.cur.kind, root.cur.isDay)] : theme.text
                        font.pixelSize: 56
                        font.family: theme.font
                        Layout.preferredWidth: 72
                        horizontalAlignment: Text.AlignHCenter
                    }

                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true

                        RowLayout {
                            spacing: 4

                            Text {
                                text: root.cur ? W.temp(root.cur.temp, root.fahrenheit) : "--"
                                color: theme.text
                                font.pixelSize: theme.displaySize
                                font.bold: true
                                font.family: theme.font
                            }

                            Text {
                                text: root.tu
                                color: theme.subtext0
                                font.pixelSize: theme.fontSize + 2
                                font.family: theme.font
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 6
                            }
                        }

                        Text {
                            text: root.cur ? root.cur.desc : ""
                            color: theme.subtext1
                            font.pixelSize: theme.fontSize
                            font.family: theme.fontUi
                        }
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Badge {
                        visible: !!root.d && root.d.aqi !== null && root.d.aqi !== undefined
                        theme: root.theme
                        text: "AQI " + (root.d ? root.d.aqi : "") + " · " + W.aqi(root.d ? root.d.aqi : null).label
                        clr: theme[W.aqi(root.d ? root.d.aqi : null).key]
                    }

                    Badge {
                        visible: !!root.cur && root.cur.uv !== null
                        theme: root.theme
                        text: "UV " + (root.cur ? root.cur.uv : "") + " · " + W.uv(root.cur ? root.cur.uv : null).label
                        clr: theme[W.uv(root.cur ? root.cur.uv : null).key]
                    }

                    Badge {
                        visible: !!root.cur
                        theme: root.theme
                        text: "Feels " + (root.cur ? W.temp(root.cur.feels, root.fahrenheit) : "") + "°"
                        clr: theme.subtext1
                    }
                }
            }

            // ── details ──
            SectionCard {
                visible: root.hasData
                theme: root.theme
                title: "Now"

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 12

                    Repeater {
                        model: root.cur ? [
                            { glyph: "", label: "Humidity", value: root.cur.humidity + "%", clr: "sapphire" },
                            { glyph: "", label: "Wind", value: (root.cur.windDir ? root.cur.windDir + " " : "") + W.wind(root.cur.wind, root.mph), clr: "teal" },
                            { glyph: "", label: "Pressure", value: root.cur.pressure + " hPa", clr: "lavender" },
                            { glyph: "", label: "Cloud cover", value: root.cur.cloud + "%", clr: "subtext1" },
                            { glyph: "", label: "Precipitation", value: root.cur.precip + " mm", clr: "blue" },
                            { glyph: "", label: "Visibility", value: root.cur.visibilityKm === null ? "--" : root.cur.visibilityKm + " km", clr: "subtext1" },
                            { glyph: "", label: "Sunrise", value: root.d.sunrise, clr: "peach" },
                            { glyph: "", label: "Sunset", value: root.d.sunset, clr: "mauve" }
                        ] : []

                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            spacing: 8

                            Text {
                                text: modelData.glyph
                                color: theme[modelData.clr] !== undefined ? theme[modelData.clr] : theme.sapphire
                                font.pixelSize: theme.fontSize + 4
                                font.family: theme.font
                                Layout.preferredWidth: 20
                                horizontalAlignment: Text.AlignHCenter
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true

                                Text {
                                    text: modelData.label
                                    color: theme.overlay0
                                    font.pixelSize: theme.fontSizeMin
                                    font.family: theme.fontUi
                                }

                                Text {
                                    text: modelData.value
                                    color: theme.text
                                    font.pixelSize: theme.fontSize - 1
                                    font.family: theme.fontUi
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }

            // ── next hours ──
            SectionCard {
                visible: root.hasData && root.d.hourly.length > 0
                theme: root.theme
                title: "Next " + (root.d ? root.d.hourly.length : 0) + " hours"

                RowLayout {
                    id: hourRow
                    Layout.fillWidth: true
                    spacing: 0

                    readonly property var temps: root.d ? root.d.hourly.map(function (h) { return h.temp }) : []
                    readonly property real tMin: Math.min.apply(null, temps)
                    readonly property real tMax: Math.max.apply(null, temps)

                    Repeater {
                        model: root.d ? root.d.hourly : []

                        ColumnLayout {
                            id: hourCol
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            spacing: 2

                            Text {
                                text: hourCol.modelData.time.slice(0, 2)
                                color: theme.overlay0
                                font.pixelSize: theme.fontSizeMin
                                font.family: theme.font
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: hourCol.modelData.icon
                                color: theme[W.kindKey(hourCol.modelData.kind, hourCol.modelData.isDay)]
                                font.pixelSize: theme.fontSize + 2
                                font.family: theme.font
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // Temperature as a dot whose height follows the value.
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30

                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: (parent.height - height) * (1 - (hourCol.modelData.temp - hourRow.tMin)
                                                                      / Math.max(1, hourRow.tMax - hourRow.tMin))
                                    color: theme.peach
                                }
                            }

                            Text {
                                text: W.temp(hourCol.modelData.temp, root.fahrenheit) + "°"
                                color: theme.text
                                font.pixelSize: theme.fontSizeMin
                                font.family: theme.font
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // Rain chance: a short bar, with the number once it matters.
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 4
                                Layout.preferredHeight: 20
                                radius: 2
                                color: theme.trackColor

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: parent.height * hourCol.modelData.rain / 100
                                    radius: 2
                                    color: theme[W.rainKey(hourCol.modelData.rain)]
                                }
                            }

                            Text {
                                text: hourCol.modelData.rain >= 20 ? hourCol.modelData.rain : ""
                                color: theme.blue
                                font.pixelSize: 9
                                font.family: theme.font
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredHeight: 10
                            }
                        }
                    }
                }
            }

            // ── week ──
            SectionCard {
                visible: root.hasData && root.d.daily.length > 0
                theme: root.theme
                title: "7 days"

                ColumnLayout {
                    id: dayCol
                    Layout.fillWidth: true
                    spacing: 6

                    readonly property var daily: root.d ? root.d.daily : []
                    readonly property real gMin: Math.min.apply(null, daily.map(function (x) { return x.min }))
                    readonly property real gMax: Math.max.apply(null, daily.map(function (x) { return x.max }))

                    Repeater {
                        model: dayCol.daily

                        RowLayout {
                            id: dayRow
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: W.dayName(dayRow.modelData.date, dayRow.index)
                                color: dayRow.index === 0 ? theme.text : theme.subtext1
                                font.pixelSize: theme.fontSize - 1
                                font.bold: dayRow.index === 0
                                font.family: theme.fontUi
                                Layout.preferredWidth: 44
                            }

                            Text {
                                text: dayRow.modelData.icon
                                color: theme[W.kindKey(dayRow.modelData.kind, true)]
                                font.pixelSize: theme.fontSize + 3
                                font.family: theme.font
                                Layout.preferredWidth: 22
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                text: dayRow.modelData.rain >= 20 ? dayRow.modelData.rain + "%" : ""
                                color: theme[W.rainKey(dayRow.modelData.rain)]
                                font.pixelSize: theme.fontSizeMin
                                font.family: theme.font
                                Layout.preferredWidth: 32
                                horizontalAlignment: Text.AlignRight
                            }

                            Text {
                                text: W.temp(dayRow.modelData.min, root.fahrenheit) + "°"
                                color: theme.subtext0
                                font.pixelSize: theme.fontSize - 1
                                font.family: theme.font
                                Layout.preferredWidth: 30
                                horizontalAlignment: Text.AlignRight
                            }

                            // Low–high span within the week's range.
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 6

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 3
                                    color: theme.trackColor
                                }

                                Rectangle {
                                    readonly property real range: Math.max(1, dayCol.gMax - dayCol.gMin)
                                    x: parent.width * (dayRow.modelData.min - dayCol.gMin) / range
                                    width: Math.max(6, parent.width * (dayRow.modelData.max - dayRow.modelData.min) / range)
                                    height: parent.height
                                    radius: 3
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0; color: theme.sapphire }
                                        GradientStop { position: 1; color: theme.peach }
                                    }
                                }
                            }

                            Text {
                                text: W.temp(dayRow.modelData.max, root.fahrenheit) + "°"
                                color: theme.text
                                font.pixelSize: theme.fontSize - 1
                                font.family: theme.font
                                Layout.preferredWidth: 30
                            }
                        }
                    }
                }
            }

            // ── units and location ──
            SectionCard {
                theme: root.theme
                title: "Settings"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Units"
                        color: theme.subtext1
                        font.pixelSize: theme.fontSize - 1
                        font.family: theme.fontUi
                        Layout.preferredWidth: 60
                    }

                    Badge {
                        theme: root.theme
                        text: "°C"
                        clr: theme.blue
                        solid: !root.fahrenheit
                        clickable: true
                        onClicked: if (root.dataSource) root.dataSource.fahrenheit = false
                    }

                    Badge {
                        theme: root.theme
                        text: "°F"
                        clr: theme.blue
                        solid: root.fahrenheit
                        clickable: true
                        onClicked: if (root.dataSource) root.dataSource.fahrenheit = true
                    }

                    Item { Layout.preferredWidth: 6 }

                    Badge {
                        theme: root.theme
                        text: "km/h"
                        clr: theme.blue
                        solid: !root.mph
                        clickable: true
                        onClicked: if (root.dataSource) root.dataSource.mph = false
                    }

                    Badge {
                        theme: root.theme
                        text: "mph"
                        clr: theme.blue
                        solid: root.mph
                        clickable: true
                        onClicked: if (root.dataSource) root.dataSource.mph = true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Location"
                        color: theme.subtext1
                        font.pixelSize: theme.fontSize - 1
                        font.family: theme.fontUi
                        Layout.preferredWidth: 60
                    }

                    Text {
                        text: root.d ? root.d.location + (root.d.country ? ", " + root.d.country : "") : "Not set"
                        color: theme.text
                        font.pixelSize: theme.fontSize - 1
                        font.family: theme.fontUi
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Badge {
                        theme: root.theme
                        text: root.locationOpen ? "Cancel" : "Change"
                        clr: theme.blue
                        clickable: true
                        onClicked: {
                            root.locationOpen = !root.locationOpen
                            if (root.locationOpen) Qt.callLater(function () { searchInput.forceActiveFocus() })
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.locationOpen
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 30
                        radius: theme.radiusMd
                        color: theme.surface1
                        border.width: searchInput.activeFocus ? 1 : 0
                        border.color: theme.blue

                        TextInput {
                            id: searchInput
                            anchors.fill: parent
                            anchors.margins: 7
                            color: theme.text
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.fontUi
                            clip: true
                            verticalAlignment: TextInput.AlignVCenter
                            Keys.onReturnPressed: root.startSearch(text)
                            Keys.onEnterPressed: root.startSearch(text)
                            Keys.onEscapePressed: event => { root.locationOpen = false; event.accepted = true }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.searching ? "Searching…" : "Search a city and press Enter"
                                color: theme.overlay0
                                font.pixelSize: theme.fontSize - 1
                                font.family: theme.fontUi
                                visible: !parent.text.length
                            }
                        }
                    }

                    Text {
                        visible: root.searchStatus !== ""
                        text: root.searchStatus
                        color: theme.yellow
                        font.pixelSize: theme.fontSizeMin
                        font.family: theme.fontUi
                    }

                    Repeater {
                        model: root.searchResults

                        Rectangle {
                            id: resultRow
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: theme.radiusMd
                            color: resultMa.containsMouse ? theme.surface1 : "transparent"

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: Text.AlignVCenter
                                text: resultRow.modelData.name
                                      + (resultRow.modelData.admin1 ? ", " + resultRow.modelData.admin1 : "")
                                      + (resultRow.modelData.country ? ", " + resultRow.modelData.country : "")
                                color: theme.text
                                font.pixelSize: theme.fontSize - 1
                                font.family: theme.fontUi
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: resultMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.chooseLocation(resultRow.modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── geocoding search ──
    Process {
        id: searchProc
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.searching = false
                try {
                    var r = JSON.parse(this.text.trim()).results || []
                    root.searchResults = r
                    root.searchStatus = r.length === 0 ? "No matches" : ""
                } catch (e) {
                    root.searchResults = []
                    root.searchStatus = "Search failed — check the connection"
                }
            }
        }

        onExited: code => {
            if (code !== 0) {
                root.searching = false
                root.searchResults = []
                root.searchStatus = "Search failed — check the connection"
            }
        }
    }

    // ── save the chosen location (the file read by weather-detail.sh) ──
    Process {
        id: saveProc
        running: false

        onExited: code => {
            if (code === 0) {
                root.locationOpen = false
                root.searchResults = []
                if (root.dataSource) root.dataSource.refresh()
            } else {
                root.searchStatus = "Could not save the location"
            }
        }
    }
}
