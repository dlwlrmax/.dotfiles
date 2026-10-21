import QtQuick
import qs.common

// Round app avatar: the phone-supplied icon when there is one, otherwise a
// coloured initial (colour derived from the app name so it stays stable).
Rectangle {
    id: avatar

    property Theme theme: ThemeStore
    property string name: ""
    property string iconPath: ""
    property int size: 28

    readonly property var palette: [theme.blue, theme.green, theme.peach, theme.mauve,
                                    theme.sapphire, theme.pink, theme.yellow, theme.lavender]
    readonly property color tint: {
        var h = 0
        for (var i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) % 997
        return palette[h % palette.length]
    }

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    color: Qt.alpha(tint, 0.2)
    clip: true

    Text {
        anchors.centerIn: parent
        visible: img.status !== Image.Ready
        text: avatar.name ? avatar.name.charAt(0).toUpperCase() : "?"
        color: avatar.tint
        font.pixelSize: avatar.size * 0.5
        font.bold: true
        font.family: avatar.theme.fontUi
    }

    Image {
        id: img
        anchors.fill: parent
        anchors.margins: 3
        source: avatar.iconPath ? "file://" + avatar.iconPath : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        smooth: true
        mipmap: true
        visible: status === Image.Ready
    }
}
