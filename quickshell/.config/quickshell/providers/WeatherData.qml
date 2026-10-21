// WeatherData
// Weather document from weather-detail.sh plus display units.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import QtQuick
import qs.common

Item {
    id: weatherData
    property Theme theme: ThemeStore
    // Poll period; DataProviders slows it down while gaming.
    property int statPollMs: 2000
    // Full document from weather-detail.sh (see there); null until the first fetch.
    property var data: null
    property bool ok: false
    property string error: ""          // "" | no-location | geocode | network
    property string errorMessage: ""
    property real updatedAt: 0
    // Display units, persisted in the shared cache table.
    property bool fahrenheit: false
    property bool mph: false
    property bool _prefsLoaded: false

    function refresh() {
        if (!weatherFetchProc.running) weatherFetchProc.running = true;
    }

    function loadPrefs() {
        var row = Db.cacheGet("weatherprefs")
        if (row) {
            try {
                var p = JSON.parse(row.json)
                fahrenheit = !!p.fahrenheit
                mph = !!p.mph
            } catch (e) {}
        }
        _prefsLoaded = true
    }

    function savePrefs() {
        if (_prefsLoaded)
            Db.cachePut("weatherprefs", JSON.stringify({ fahrenheit: fahrenheit, mph: mph }))
    }

    onFahrenheitChanged: savePrefs()
    onMphChanged: savePrefs()
    Component.onCompleted: loadPrefs()

    Process {
        id: weatherFetchProc
        command: [theme.scriptDir + "/weather-detail.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text.trim());
                    if (d.ok) {
                        weatherData.data = d;
                        weatherData.ok = true;
                        weatherData.updatedAt = d.updated;
                        weatherData.error = "";
                        weatherData.errorMessage = "";
                    } else {
                        // Keep the last good data (ok stays true) so the bar
                        // and panel show it as stale instead of blanking.
                        weatherData.error = d.error || "network";
                        weatherData.errorMessage = d.message || "";
                        if (d.error === "no-location" || d.error === "geocode") {
                            weatherData.ok = false;
                            weatherData.data = null;
                        }
                    }
                } catch (e) {
                    weatherData.error = "network";
                    weatherData.errorMessage = "Unreadable weather response";
                }
            }
        }
    }

    // Retry soon after a failure (e.g. the shell started before the network was up).
    Timer {
        interval: 45000
        running: weatherData.error === "network" || weatherData.error === "" && !weatherData.ok
        repeat: true
        onTriggered: weatherData.refresh()
    }

    // Open-Meteo refreshes about every 15 minutes.
    Timer {
        interval: 900000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherData.refresh()
    }
}
