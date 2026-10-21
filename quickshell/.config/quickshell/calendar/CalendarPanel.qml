import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import qs.common
import "../common/CalendarLogic.js" as Cal

Item {
    id: root
    property Theme theme: ThemeStore
    property bool active: false
    signal close()

    property date today: new Date()
    readonly property int todayKey: Cal.keyOf(today)
    property int calYear: today.getFullYear()
    // -1 = 12-month overview, 0..11 = zoomed month
    property int zoomMonth: -1
    // en_GB gives Monday-first weeks (MonthGrid follows the locale; MonthView's
    // dayHeaders must match).
    readonly property var calLocale: Qt.locale("en_GB")

    // Day selection: click a day, click a second one for a range.
    property int selStart: 0
    property int selEnd: 0

    readonly property bool showingToday: calYear === today.getFullYear()
                                         && (zoomMonth < 0 || zoomMonth === today.getMonth())
    readonly property string title: zoomMonth < 0 ? String(calYear)
                                                  : Cal.MONTHS_LONG[zoomMonth] + " " + calYear
    readonly property var infoParts: selStart === 0 ? Cal.describeParts(todayKey, todayKey)
        : selEnd === 0 ? Cal.describeParts(selStart, todayKey)
        : Cal.describeRangeParts(selStart, selEnd)

    // Badge color per info-segment kind.
    function badgeColor(kind) {
        switch (kind) {
        case "week":    return theme.blue
        case "lunar":   return theme.peach
        case "holiday": return theme.red
        case "obs":     return theme.sapphire
        case "today":   return theme.highlight
        case "future":  return theme.green
        case "span":    return theme.highlight
        case "day":     return theme.subtext1
        default:        return theme.subtext0   // past
        }
    }

    clip: true
    focus: true
    // Cap to the screen so the fixed panel never spills off small displays;
    // when the 12-month grid no longer fits, gridScroll scrolls instead.
    implicitWidth: Math.min(theme.panelWidthXL, Screen.width * 0.9)
    implicitHeight: Math.min(640, Screen.height * 0.9)

    function goToToday() {
        today = new Date()
        calYear = today.getFullYear()
        if (zoomMonth >= 0) zoomMonth = today.getMonth()
    }

    // Move by a year (overview) or a month (zoomed), wrapping across years.
    function shift(n) {
        if (zoomMonth < 0) {
            calYear += n
        } else {
            var m = zoomMonth + n
            calYear += Math.floor(m / 12)
            zoomMonth = ((m % 12) + 12) % 12
        }
    }

    function pick(key) {
        if (selStart === 0 || selEnd !== 0) {
            selStart = key
            selEnd = 0
        } else if (key === selStart) {
            selStart = 0
        } else {
            var a = selStart
            selStart = Math.min(a, key)
            selEnd = Math.max(a, key)
        }
    }

    // One step per wheel notch (touchpads accumulate to a notch first).
    property real _wheelAcc: 0
    function wheelStep(angleDeltaY) {
        _wheelAcc += angleDeltaY
        if (_wheelAcc >= 120) { shift(-1); _wheelAcc = 0 }
        else if (_wheelAcc <= -120) { shift(1); _wheelAcc = 0 }
    }

    // Only reassign on a real date change: every cell binds to `today`.
    function _refreshDay() {
        var d = new Date()
        if (d.toDateString() !== today.toDateString()) today = d
    }

    // Always current when opened (covers midnight crossing + wake from sleep)
    onActiveChanged: if (active) root._refreshDay()

    // Midnight rollover while the panel stays open
    Timer {
        interval: 60000
        running: root.active
        repeat: true
        onTriggered: root._refreshDay()
    }

    Keys.onLeftPressed: root.shift(-1)
    Keys.onRightPressed: root.shift(1)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_PageUp) { root.shift(-1); event.accepted = true }
        else if (event.key === Qt.Key_PageDown) { root.shift(1); event.accepted = true }
        else if (event.key === Qt.Key_Home || event.key === Qt.Key_T) { root.goToToday(); event.accepted = true }
    }
    // Esc peels back one layer at a time: selection, zoom, then closes the panel.
    Keys.onEscapePressed: event => {
        if (root.selStart !== 0) { root.selStart = 0; root.selEnd = 0; event.accepted = true }
        else if (root.zoomMonth >= 0) { root.zoomMonth = -1; event.accepted = true }
        else event.accepted = false
    }

    onCalYearChanged: fade.restart()
    onZoomMonthChanged: fade.restart()

    PanelBackground {
        anchors.fill: parent
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: theme.panelMargin
        spacing: 8

        // ── header ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            IconButton { theme: root.theme; text: Glyphs.prev; onClicked: root.shift(-1) }

            // Year/month title. Zoomed: click to go back to the overview.
            // Overview: click to jump to today. Wheel steps year/month.
            Text {
                text: root.title
                color: titleMa.containsMouse ? theme.highlight : theme.text
                font.pixelSize: theme.fontSize + 4
                font.bold: true
                font.family: theme.font
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter

                MouseArea {
                    id: titleMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.zoomMonth >= 0 ? root.zoomMonth = -1 : root.goToToday()
                    onWheel: wheel => root.wheelStep(wheel.angleDelta.y)
                }
            }

            IconButton {
                theme: root.theme
                text: "Today"
                glyphSize: theme.fontSize - 1
                implicitWidth: 52
                visible: !root.showingToday
                onClicked: root.goToToday()
            }

            IconButton { theme: root.theme; text: Glyphs.next; onClicked: root.shift(1) }
            IconButton { theme: root.theme; text: Glyphs.close; glyphSize: theme.fontSize + 1; onClicked: root.close() }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.surface0
        }

        Item {
            id: content
            Layout.fillWidth: true
            Layout.fillHeight: true

            NumberAnimation {
                id: fade
                target: content
                property: "opacity"
                from: 0.3
                to: 1
                duration: 160
                easing.type: Easing.OutCubic
            }

            // ── 12-month overview (4 cols × 3 rows) ──
            // ScrollView: fills exactly when the grid fits the capped height,
            // scrolls (instead of clipping months) when the screen is short.
            ScrollView {
                id: gridScroll
                anchors.fill: parent
                visible: root.zoomMonth < 0
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                GridLayout {
                    id: yearGrid
                    width: gridScroll.availableWidth
                    height: Math.max(implicitHeight, gridScroll.availableHeight)
                    columns: 4
                    rowSpacing: 10
                    columnSpacing: 14

                    Repeater {
                        model: 12

                        delegate: MonthView {
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1   // equal columns regardless of content
                            theme: root.theme
                            year: root.calYear
                            month: index
                            todayKey: root.todayKey
                            selStart: root.selStart
                            selEnd: root.selEnd
                            calLocale: root.calLocale
                            onDayClicked: key => root.pick(key)
                            onTitleClicked: root.zoomMonth = index
                        }
                    }
                }
            }

            // ── zoomed month ──
            Loader {
                anchors.fill: parent
                active: root.zoomMonth >= 0

                sourceComponent: MonthView {
                    big: true
                    theme: root.theme
                    year: root.calYear
                    month: root.zoomMonth
                    todayKey: root.todayKey
                    selStart: root.selStart
                    selEnd: root.selEnd
                    calLocale: root.calLocale
                    onDayClicked: key => root.pick(key)

                    WheelHandler {
                        onWheel: event => root.wheelStep(event.angleDelta.y)
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.surface0
        }

        // Selected day / range (today when nothing is selected), as badges.
        Flow {
            Layout.fillWidth: true
            Layout.preferredHeight: 2 * 22 + 6
            spacing: 6

            Repeater {
                model: root.infoParts

                delegate: Rectangle {
                    id: badge
                    required property var modelData
                    readonly property bool plain: modelData.kind === "date" || modelData.kind === "arrow"
                    readonly property bool solid: modelData.kind === "today"
                    readonly property color clr: root.badgeColor(modelData.kind)

                    implicitWidth: label.implicitWidth + (plain ? 0 : 14)
                    implicitHeight: 22
                    radius: theme.radiusMd
                    color: plain ? "transparent"
                         : solid ? clr : Qt.alpha(clr, 0.16)
                    border.width: plain || solid ? 0 : 1
                    border.color: Qt.alpha(clr, 0.35)

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: badge.modelData.t
                        color: badge.plain ? (modelData.kind === "date" ? theme.text : theme.subtext0)
                             : badge.solid ? theme.base : badge.clr
                        font.pixelSize: theme.fontSize - 1
                        font.bold: badge.plain && modelData.kind === "date" || badge.solid
                        font.family: theme.font
                    }
                }
            }
        }
    }
}
