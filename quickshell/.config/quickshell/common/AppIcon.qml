import Quickshell
import QtQuick

Item {
    id: root

    required property string appId
    property string iconName: ""
    property string fallbackIcon: "application-x-executable"
    property string fallbackGlyph: ""
    property real size: 16
    property bool hideOnMissing: false

    readonly property string _resolvedName: iconName.length > 0 ? iconName : iconMap.resolve(appId)
    readonly property bool _isFilePath: _resolvedName.includes("/")
    readonly property string _effectiveName: {
        if (!_resolvedName || _isFilePath) return _resolvedName
        if (Quickshell.hasThemeIcon(_resolvedName)) return _resolvedName
        var lower = _resolvedName.toLowerCase()
        return Quickshell.hasThemeIcon(lower) ? lower : _resolvedName
    }
    readonly property string _iconSource: {
        if (!_resolvedName) return ""
        if (_isFilePath) return "file://" + _resolvedName
        return Quickshell.iconPath(_effectiveName, fallbackIcon)
    }
    readonly property bool _canTryIcon: _iconSource.length > 0
    readonly property bool iconFound: _canTryIcon && img.status !== Image.Error && img.status !== Image.Null

    width: size
    height: size

    // Nerd Font glyph fallback
    Text {
        anchors.centerIn: parent
        visible: (!_canTryIcon || img.status === Image.Error) && fallbackGlyph.length > 0
        text: fallbackGlyph
        color: "#cdd6f4"
        font.family: "JetBrainsMono Nerd Font Mono"
        font.pixelSize: Math.round(size * 0.9)
    }

    Image {
        id: img
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        antialiasing: true
        smooth: true
        mipmap: true
        sourceSize.width: 48
        sourceSize.height: 48

        visible: _canTryIcon && status !== Image.Error

        IconMap { id: iconMap }

        source: _iconSource
    }
}
