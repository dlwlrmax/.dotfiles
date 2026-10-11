import QtQuick

QtObject {
    id: root

    readonly property var map: ({
        "zen": "zen-browser",
        "Zen": "zen-browser",
        "google-chrome": "google-chrome",
        "com.mitchellh.ghostty": "com.mitchellh.ghostty",
        "Thunar": "org.xfce.thunar",
        "com.stremio.stremio": "com.stremio.Stremio",
        "EasyEffects": "easyeffects",
        "com.github.wwmm.easyeffects": "easyeffects",
        "easyeffects": "easyeffects"
    })

    function resolve(appId) {
        if (!appId) return ""
        return map[appId] || appId
    }
}
