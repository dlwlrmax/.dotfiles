// DataProviders — instantiates the shared data sources (providers/*.qml) and owns the
// cross-cutting state: the gaming profile and the poll period it slows down.
import Quickshell
import Quickshell.Io
import QtQuick
import qs.common
import qs.providers

Item {
    id: root
    property Theme theme: ThemeStore
    property alias kdeData: kdeData
    property alias notifServer: notifData.notifServer
    property alias notifData: notifData
    property alias cpuData: cpuData
    property alias netData: netData
    property alias weatherData: weatherData
    property alias volumeData: volumeData
    property alias batteryData: batteryData
    property alias healthData: healthData
    property alias wallpaperData: wallpaperData

    // Set by Hyprland's gaming profile (hypr lua/gaming.lua via `qs ipc call
    // gaming set`). While true: no popups on the game's monitor (chimes still
    // play), bar stat polls slowed down.
    property bool gaming: false
    // Monitor focused when gaming turned on = the game's monitor (the profile only
    // engages while the fullscreen game is the active window).
    property string gamingMonitor: ""
    readonly property int statPollMs: gaming ? 10000 : 2000

    function cycleAudio() { volumeData.cycleSink() }

    // ── Providers (one file each, see providers/) ───────────
    KdeData { id: kdeData; theme: root.theme }
    NotifData { id: notifData; theme: root.theme }
    CpuData { id: cpuData; statPollMs: root.statPollMs }
    NetData { id: netData; statPollMs: root.statPollMs }
    WeatherData { id: weatherData; theme: root.theme }
    VolumeData { id: volumeData; theme: root.theme }
    BatteryData { id: batteryData; theme: root.theme }
    WallpaperData { id: wallpaperData; theme: root.theme }
    HealthData { id: healthData; theme: root.theme; weather: weatherData; kde: kdeData; net: netData; cpu: cpuData }
}
