import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import "WeatherLogic.js" as W

// Bar widget: condition glyph (coloured by condition, moon at night) and the
// temperature. Hover for the details; click opens the panel.
Item {
    id: root
    property Theme theme: ThemeStore
    property var dataSource: null
    signal togglePanel()

    readonly property bool hasData: !!dataSource && dataSource.ok && !!dataSource.data
    readonly property var cur: hasData ? dataSource.data.current : null
    readonly property bool fahrenheit: dataSource ? dataSource.fahrenheit : false
    readonly property bool stale: !!dataSource && dataSource.error !== "" && hasData
    readonly property color iconClr: cur ? theme[W.kindKey(cur.kind, cur.isDay)] : theme.subtext0

    function refresh() {
        if (dataSource) dataSource.refresh()
    }

    function tipText() {
        if (!dataSource) return ""
        if (!hasData) {
            return dataSource.error === "no-location" ? "Weather: set a location (click to open)"
                 : dataSource.errorMessage || "Weather unavailable"
        }
        var d = dataSource.data, cur = d.current, f = fahrenheit, u = W.tempUnit(f)
        var today = d.daily.length ? d.daily[0] : null
        var rain = 0
        for (var i = 0; i < Math.min(6, d.hourly.length); i++) rain = Math.max(rain, d.hourly[i].rain)
        var lines = [d.location + ": " + cur.desc + ", " + W.temp(cur.temp, f) + u,
                     "Feels " + W.temp(cur.feels, f) + u + " · Humidity " + cur.humidity + "%"]
        if (today) lines.push("High " + W.temp(today.max, f) + u + " · Low " + W.temp(today.min, f) + u
                              + " · Rain " + rain + "% (next 6h)")
        if (d.aqi !== null) lines.push("AQI " + d.aqi + " · " + W.aqi(d.aqi).label)
        lines.push(stale ? "Update failed — showing " + W.clock(dataSource.updatedAt) : "Updated " + W.clock(dataSource.updatedAt))
        return lines.join("\n")
    }

    // Hard containment: layout squeeze must never paint over neighbors.
    clip: true
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    opacity: stale ? 0.6 : 1

    RowLayout {
        id: row
        spacing: 4

        Text {
            id: iconText
            text: root.cur ? root.cur.icon : ""
            color: root.iconClr
            // Material weather glyphs: filled, so they read at the same weight as the other bar icons.
            font.pixelSize: theme.fontSize + 14
            font.family: theme.font
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 28
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            id: textText
            text: root.cur ? W.temp(root.cur.temp, root.fahrenheit) + "°" : "--"
            color: theme.subtext0
            font.pixelSize: theme.fontSize
            font.weight: Font.Medium
            font.family: theme.font
            Layout.alignment: Qt.AlignVCenter
        }
    }

    BarTooltip {
        target: root
        theme: root.theme
        hovered: ma.containsMouse
        text: root.tipText()
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.togglePanel()
            }
        }
    }
}
