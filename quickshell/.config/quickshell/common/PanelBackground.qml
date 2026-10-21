import QtQuick

// Standard panel chrome: flush with the bar on top, rounded below, hairline
// border. Place as the first child of a panel root with `anchors.fill: parent`.
Rectangle {
    id: bg

    property Theme theme: ThemeStore
    // Panels are opaque by default so busy windows behind don't bleed through.
    property bool translucent: false

    topLeftRadius: 0
    topRightRadius: 0
    bottomLeftRadius: theme.panelRadius
    bottomRightRadius: theme.panelRadius
    color: translucent ? theme.panelColor : theme.panelColorSolid
    // Lighter 1px edge so the panel separates from busy windows behind it.
    border.color: Qt.alpha(theme.surface1, 0.9)
    border.width: 1

    // mask the top border so the panel joins the bar
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: bg.border.width + 1
        color: bg.color
    }
}
