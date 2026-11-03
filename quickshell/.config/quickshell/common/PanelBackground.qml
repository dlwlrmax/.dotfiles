import QtQuick

// Standard panel chrome: same colour as the bar and flush with it (PanelOverlay
// draws the concave joins), rounded below. Place as the first child of a panel root
// with `anchors.fill: parent`.
Rectangle {
    id: bg

    property Theme theme: ThemeStore
    topLeftRadius: 0
    topRightRadius: 0
    bottomLeftRadius: theme.panelRadius
    bottomRightRadius: theme.panelRadius
    color: theme.barColor
}
