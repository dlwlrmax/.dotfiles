import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common

// Bar indicator for a battery that needs attention (low or charging): the lowest
// such device's glyph and percentage. Hidden while everything is fine.
Item {
    id: root
    property Theme theme: ThemeStore
    property var dataSource: null
    signal togglePanel(int centerX)

    readonly property var dev: dataSource ? dataSource.attention : null
    readonly property bool charging: !!dev && dev.status === "Charging"
    readonly property int pct: dev ? dataSource.level(dev) : 0
    readonly property color clr: !dev ? theme.subtext0 : charging ? theme.green
                                : pct <= 10 ? theme.red : pct <= 20 ? theme.peach : theme.yellow

    function glyph() {
        if (charging) return "󰂄"
        return pct <= 10 ? "󰁺" : pct <= 30 ? "󰁼" : pct <= 60 ? "󰁾" : "󰂀"
    }

    // Hard containment: layout squeeze must never paint over neighbors.
    clip: true
    visible: !!dev && Prefs.show("battery")
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    RowLayout {
        id: row
        spacing: 3

        Text {
            text: root.glyph()
            color: root.clr
            font.pixelSize: theme.fontSize + 8
            font.family: theme.font
        }

        Text {
            text: typeof (root.dev ? root.dev.capacity : null) === "number" ? root.pct + "%" : (root.dev ? root.dev.capacity_level : "")
            color: root.clr
            font.pixelSize: theme.fontSize - 1
            font.weight: Font.Medium
            font.family: theme.font
        }
    }

    BarTooltip {
        target: root
        theme: root.theme
        hovered: ma.containsMouse && !!root.dev
        text: root.dev ? root.dataSource.label(root.dev) + "\n" + (root.charging ? "Charging" : "Low battery")
                         + (root.dataSource.minutesLeft(root.dev) >= 0 ? "\n~" + root.dataSource.fmtMinutes(root.dataSource.minutesLeft(root.dev)) + " left" : "")
                       : ""
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            var p = root.mapToItem(null, 0, 0)
            root.togglePanel(p.x + root.width / 2)
        }
    }
}
