import QtQuick

// Small rotating glyph: "something is in progress, wait". Only animates while visible.
Text {
    id: spinner
    property Theme theme: ThemeStore
    property int size: theme.fontSizeMin
    property bool running: true

    text: ""   // nf-fa-spinner
    color: theme.subtext0
    font.pixelSize: size
    font.family: theme.font
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    RotationAnimator on rotation {
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
        running: spinner.running && spinner.visible
    }
}
