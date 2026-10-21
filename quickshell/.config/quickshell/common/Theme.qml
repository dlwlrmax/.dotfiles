import Quickshell
import QtQuick

// Design tokens. Instantiated once as the ThemeStore singleton; components keep a
// `theme` property (defaulting to ThemeStore) so a different Theme can still be
// injected, e.g. for previews.
QtObject {
    // ── Palette: Catppuccin Mocha ──
    readonly property color base: ShellPalette.get("base", "#1e1e2e")
    readonly property color mantle: ShellPalette.get("mantle", "#181825")
    readonly property color crust: ShellPalette.get("crust", "#11111b")
    readonly property color surface0: ShellPalette.get("surface0", "#313244")
    readonly property color surface1: ShellPalette.get("surface1", "#45475a")
    readonly property color surface2: ShellPalette.get("surface2", "#585b70")
    readonly property color overlay0: ShellPalette.get("overlay0", "#6c7086")
    readonly property color overlay1: ShellPalette.get("overlay1", "#7f849c")
    readonly property color overlay2: ShellPalette.get("overlay2", "#9399b2")
    readonly property color text: ShellPalette.get("text", "#cdd6f4")
    readonly property color subtext0: ShellPalette.get("subtext0", "#a6adc8")
    readonly property color subtext1: ShellPalette.get("subtext1", "#bac2de")
    readonly property color lavender: ShellPalette.get("lavender", "#b4befe")
    readonly property color blue: ShellPalette.get("blue", "#89b4fa")
    readonly property color sapphire: ShellPalette.get("sapphire", "#74c7ec")
    readonly property color teal: ShellPalette.get("teal", "#94e2d5")
    readonly property color sky: ShellPalette.get("sky", "#89dceb")
    readonly property color red: ShellPalette.get("red", "#f38ba8")
    readonly property color green: ShellPalette.get("green", "#a6e3a1")
    readonly property color yellow: ShellPalette.get("yellow", "#f9e2af")
    readonly property color peach: ShellPalette.get("peach", "#fab387")
    readonly property color maroon: ShellPalette.get("maroon", "#eba0ac")
    readonly property color mauve: ShellPalette.get("mauve", "#cba6f7")
    readonly property color pink: ShellPalette.get("pink", "#f5c2e7")
    readonly property color flamingo: ShellPalette.get("flamingo", "#f2cdcd")
    readonly property color rosewater: ShellPalette.get("rosewater", "#f5e0dc")

    // ── Semantic roles ──
    // Highlight colour (today marker, play button, search focus, ...): a palette
    // colour chosen in Settings (Prefs.accentName).
    readonly property string accentName: Prefs.accentName
    readonly property color highlight: {
        switch (accentName) {
        case "auto": return ShellPalette.get("highlight", mauve)
        case "blue": return blue
        case "lavender": return lavender
        case "sapphire": return sapphire
        case "sky": return sky
        case "green": return green
        case "yellow": return yellow
        case "peach": return peach
        case "pink": return pink
        case "red": return red
        default: return mauve
        }
    }

    // Text/glyphs on a saturated fill (badges, counters, urgent workspace).
    readonly property color onAccent: "#ffffff"
    // Panel background: translucent for overlays that want to show through,
    // solid for panels (see PanelBackground).
    readonly property color panelColor: Qt.rgba(base.r, base.g, base.b, 0.95)
    readonly property color panelColorSolid: Qt.rgba(base.r, base.g, base.b, 1)
    readonly property color barColor: Qt.rgba(base.r, base.g, base.b, 0.6)
    // Dark inset behind progress/level bars.
    readonly property color trackColor: Qt.darker(surface0, 1.2)
    readonly property color trackOverlay: Qt.rgba(0, 0, 0, 0.2)

    // Group background behind related bar widgets.
    readonly property color capsuleColor: Qt.alpha(surface0, 0.55)

    // Green/yellow/red by load: above `crit` red, above `warn` yellow.
    function severity(value, warn, crit) {
        return value > crit ? red : value > warn ? yellow : green
    }

    // ── Typography ──
    readonly property int fontSize: 12
    // Mono (with Nerd Font glyphs) for numbers, icons and the bar; the proportional
    // UI font for prose (notification text, weather, track titles).
    readonly property string font: "JetBrainsMono Nerd Font Mono"
    readonly property string fontUi: "Inter"
    // Readability floor for panel text; hierarchy below body size comes from color.
    readonly property int fontSizeMin: 11
    readonly property int iconSize: 16                  // inline glyph icons
    readonly property int displaySize: 36               // weather temperature

    // ── Shape / spacing scale ──
    readonly property int radiusSm: 4
    readonly property int radiusMd: 6
    readonly property int radiusLg: 8
    readonly property int radiusXl: 12
    readonly property int panelRadius: 16
    readonly property int panelMargin: 14
    // Panel widths: small / medium / large / calendar-sized.
    readonly property int panelWidthS: 360
    readonly property int panelWidthM: 420
    readonly property int panelWidthL: 480
    readonly property int panelWidthXL: 720

    // Output volume accent / glyph, shared by the bar, the OSD and the quick controls.
    function volumeColor(level, muted) {
        return muted ? surface1
             : level > volumeCriticalLevel ? volumeCriticalColor
             : level > volumeWarnLevel ? volumeWarnColor
             : level > volumeElevatedLevel ? volumeElevatedColor : volumeNormalColor
    }

    function volumeGlyph(level, muted) {
        return muted ? "󰝟" : level > 70 ? "󰕾" : level > 30 ? "󰖀" : "󰕿"
    }

    // Bar height: shared by the bar window in shell.qml and every panel/OSD
    // offset anchored below it.
    readonly property int barHeight: 44

    // ── Thresholds ──
    // Volume / OSD level thresholds and their accent colors.
    readonly property int volumeCriticalLevel: 80
    readonly property int volumeWarnLevel: 50
    readonly property int volumeElevatedLevel: 30
    readonly property color volumeCriticalColor: red
    readonly property color volumeWarnColor: yellow
    readonly property color volumeElevatedColor: peach
    readonly property color volumeNormalColor: green

    // Bar CPU/GPU widget load bands. Deliberately more eager than the panel's
    // sparkline bands below: the bar is the always-visible alert.
    readonly property int cpuLoadCrit: 70
    readonly property int cpuLoadWarn: 30
    readonly property int cpuTempCrit: 85
    readonly property int cpuTempHigh: 70
    readonly property int cpuTempWarn: 50

    // RAM / swap bands, shared by the bar widget and SysUsagePanel.
    readonly property int ramCrit: 80
    readonly property int ramWarn: 50
    readonly property int swapCrit: 50
    readonly property int swapWarn: 20

    // SysUsagePanel sparkline bands (CPU/GPU) and process-list color bands.
    readonly property int sysCpuLineCrit: 80
    readonly property int sysCpuLineWarn: 50
    readonly property int sysGpuLineCrit: 70
    readonly property int sysGpuLineWarn: 40
    readonly property int sysProcRamCrit: 1024
    readonly property int sysProcRamWarn: 512
    readonly property int sysProcCpuCrit: 20
    readonly property int sysProcCpuWarn: 10
    readonly property int sysDiskWarn: 80
    readonly property int sysDiskCrit: 90
    // Bar net widget tints a direction once it moves more than this (bytes/s).
    readonly property int netActiveBps: 10240

    // Central script path. Honors XDG_CONFIG_HOME, else ~/.config.
    readonly property string scriptDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quickshell/scripts"
}
