import Quickshell
import QtQuick

Image {
    id: root

    required property string appId
    property string fallbackIcon: "application-x-executable"
    property real size: 16
    property bool hideOnMissing: false

    readonly property string resolvedName: iconMap.resolve(appId)
    readonly property bool isFilePath: resolvedName.includes("/")
    readonly property string effectiveName: {
        if (!resolvedName || isFilePath) return resolvedName
        if (Quickshell.hasThemeIcon(resolvedName)) return resolvedName
        var lower = resolvedName.toLowerCase()
        return Quickshell.hasThemeIcon(lower) ? lower : resolvedName
    }
    readonly property bool iconFound: {
        if (!resolvedName) return false
        if (isFilePath) return true
        return Quickshell.hasThemeIcon(effectiveName)
    }
    readonly property bool hasError: status === Image.Error

    width: size
    height: size
    fillMode: Image.PreserveAspectFit
    antialiasing: true
    smooth: true
    mipmap: true
    sourceSize.width: 48
    sourceSize.height: 48

    visible: !hideOnMissing || iconFound

    IconMap { id: iconMap }

    source: {
        if (!resolvedName) return ""
        if (isFilePath) return "file://" + resolvedName
        return Quickshell.iconPath(effectiveName, fallbackIcon)
    }
}
