import Quickshell
import QtQuick

QtObject {
    readonly property string base: "#1e1e2e"
    readonly property string mantle: "#181825"
    readonly property string crust: "#11111b"
    readonly property string surface0: "#313244"
    readonly property string surface1: "#45475a"
    readonly property string text: "#cdd6f4"
    readonly property string subtext0: "#a6adc8"
    readonly property string subtext1: "#bac2de"
    readonly property string lavender: "#b4befe"
    readonly property string blue: "#89b4fa"
    readonly property string sapphire: "#74c7ec"
    readonly property string sky: "#89dceb"
    readonly property string red: "#f38ba8"
    readonly property string green: "#a6e3a1"
    readonly property string yellow: "#f9e2af"
    readonly property string peach: "#fab387"
    // Catppuccin Mocha canonical values. maroon/rosewater previously duplicated
    // pink (#f5c2e7) — copy-paste typo. Unused elsewhere, so no visual change.
    readonly property string maroon: "#eba0ac"
    readonly property string mauve: "#cba6f7"
    readonly property string pink: "#f5c2e7"
    readonly property string flamingo: "#f2cdcd"
    readonly property string rosewater: "#f5e0dc"
    readonly property string black: "#1e1e2e"
    readonly property string white: "#fff"

    // Volume / OSD level thresholds and their accent colors. Previously the
    // threshold chain was duplicated as literals in Volume.qml and OsdPopup.qml.
    readonly property int volumeCriticalLevel: 80
    readonly property int volumeWarnLevel: 50
    readonly property int volumeElevatedLevel: 30
    readonly property string volumeCriticalColor: red
    readonly property string volumeWarnColor: yellow
    readonly property string volumeElevatedColor: peach
    readonly property string volumeNormalColor: green

    // Bar height: shared by the bar window in shell.qml and every panel/OSD
    // offset anchored below it.
    readonly property int barHeight: 44

    // CPU widget usage/temperature thresholds (see cpu/Cpu.qml).
    readonly property int cpuLoadCrit: 70
    readonly property int cpuLoadWarn: 30
    readonly property int cpuTempCrit: 85
    readonly property int cpuTempHigh: 70
    readonly property int cpuTempWarn: 50
    readonly property int ramCrit: 80
    readonly property int ramWarn: 50
    readonly property int swapCrit: 50
    readonly property int swapWarn: 20

    readonly property int fontSize: 12
    readonly property string font: "JetBrainsMono Nerd Font Mono"

    // Central script path. Honors XDG_CONFIG_HOME, else ~/.config — same
    // resolved value as the previously hardcoded HOME prefix when XDG is unset.
    readonly property string scriptDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quickshell/scripts"

    readonly property color color: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.95)
}
