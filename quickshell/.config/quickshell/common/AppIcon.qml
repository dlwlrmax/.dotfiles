import Quickshell
import QtQuick

Image {
    id: root

    required property string appId
    property string fallbackIcon: "image://icon/application-x-executable"
    property real size: 16

    width: size
    height: size
    fillMode: Image.PreserveAspectFit
    antialiasing: true
    smooth: true
    mipmap: true
    sourceSize.width: 48
    sourceSize.height: 48

    IconMap { id: iconMap }

    source: {
        var iconName = iconMap.resolve(appId)
        return iconName ? Quickshell.iconPath(iconName, fallbackIcon) : ""
    }

    visible: source.toString().length > 0
}
